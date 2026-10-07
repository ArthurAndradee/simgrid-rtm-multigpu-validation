# shellcheck shell=bash
# ---------------------------------------------------------------------------
# resilience.sh — reactive node re-census, orphan process cleanup, and
# in-flight run tracking for crash-safe resume. See design doc secoes
# 5.4/6.3(O1)/8. Separate from lib/setup.sh on purpose: setup.sh is about
# INITIAL provisioning (SSH mesh, GPU census, Nix bootstrap, all of it
# expected to die() loudly on failure); this file is about ONGOING
# campaign resilience, where a dead node or a crashed run is an EXPECTED,
# recoverable condition, not a reason to abort everything.
# ---------------------------------------------------------------------------

: "${INFLIGHT_FILE:=$STATE_DIR/inflight.txt}"

# Short-timeout SSH options for the liveness probe — deliberately
# DIFFERENT from $SSH_OPTS (ConnectTimeout=20): a probe whose entire
# purpose is "detect dead nodes fast" must not wait 20s per candidate,
# even in parallel (large N would still serialize on the wait loop below
# once dead-node timeouts start dominating).
LIVENESS_SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
                   -o ConnectTimeout=5 -o BatchMode=yes -o LogLevel=ERROR)

# nodes_liveness_probe — REACTIVE (the caller decides WHEN to invoke this;
# there is no periodic background poller in v1 — see design doc secao 8:
# campaign correctness does not require using every possible node, only
# not hanging on ones that are gone; recovering a node that flaps back up
# mid-campaign is an optimization, deliberately out of scope here).
#
# Distinct from lib/setup.sh's gpu_census, which die()s the whole campaign
# on ANY ssh failure — unusable here, since a dead node is the EXACT,
# expected condition this function exists to handle. Runs every host from
# $NODES_FILE (the ORIGINAL allocation, never itself modified) in
# parallel, background+wait (no single slow/dead host blocks the sweep —
# same mitigation pattern as orphan_cleanup below), and writes
# $NODES_ALIVE_FILE with only the hosts that answered. core.sh's nodes()
# picks this up automatically for every caller.
#
# Echoes the number of alive nodes found.
nodes_liveness_probe() {
  local tmp_dir; tmp_dir=$(mktemp -d)
  local h pids=() hosts=()

  for h in $(grep -v '^[[:space:]]*$' "$NODES_FILE"); do
    ( ssh "${LIVENESS_SSH_OPTS[@]}" "root@$h" true >/dev/null 2>&1 \
        && : > "$tmp_dir/$h.alive" ) &
    pids+=("$!"); hosts+=("$h")
  done
  local i
  for i in "${!pids[@]}"; do wait "${pids[$i]}" || true; done

  : > "$NODES_ALIVE_FILE"
  local alive=0 dead=()
  for h in "${hosts[@]}"; do
    if [ -f "$tmp_dir/$h.alive" ]; then
      echo "$h" >> "$NODES_ALIVE_FILE"
      alive=$((alive + 1))
    else
      dead+=("$h")
    fi
  done
  rm -rf "$tmp_dir"

  if [ "${#dead[@]}" -gt 0 ]; then
    warn "nodes_liveness_probe: ${#dead[@]}/${#hosts[@]} nó(s) inalcançável(is): ${dead[*]} — excluído(s) de nodes_alive.txt (nodes.txt original preservado para auditoria)"
    diary "Re-censo reativo de nós: ${#dead[@]} inalcançável(is) (${dead[*]}). $alive/${#hosts[@]} vivos — linhas exigindo mais nós que isso passam a DEFER automaticamente (csv_each_compatible_row usa AVAIL atualizado)."
  else
    log "nodes_liveness_probe: todos os ${#hosts[@]} nós respondendo"
  fi
  echo "$alive"
}

# orphan_cleanup — sweep every node in nodes() (the current ALIVE set) for
# leftover dc/mpirun/prterun/prted processes from a previous (possibly
# crashed) run: TERM, brief wait, KILL survivors. Must run (a) before
# every launch (defensive) and (b) right after any failure (reactive).
#
# Matches '[.]/bin/dc' — NOT the substring 'bin/dc'. [EMP, session
# 2026-07-10]: pgrep/pkill -f 'bin/dc' also matches 'sbin/dcgm'
# (dcgm-exporter) because "bin/dc" is literally a substring of
# "sbin/dcgm" (s-B-I-N-/-D-C-gm) — killing an unrelated monitoring daemon
# was the actual mistake made on-hardware that session. The '[.]/bin/dc'
# regex requires a literal dot before "bin", which "sbin/dcgm" does not
# have.
#
# An unreachable node is skipped with a warning (node_bad), never blocks
# the sweep — nodes() already reflects the latest liveness probe, and each
# per-node ssh_root call has its own timeout via $SSH_OPTS.
orphan_cleanup() {
  local h failed=()
  for h in $(nodes); do
    # Two bugs found and fixed together 2026-07-18, entirely off-cluster
    # (chiclet-1, no chuc needed — both are plain procps/regex behavior,
    # not hardware-specific):
    #   (1) '-E' is not a real pkill/pgrep flag on this procps build
    #       ("invalid option -- 'E'", rc=2) — -f alone already treats the
    #       pattern as an extended regex (verified: 'a|b' alternation
    #       matches through -f with no -E needed). With the (invalid) -E
    #       present, every 'mpirun|prterun|prted' line below silently
    #       failed every single time, swallowed by 2>/dev/null; since this
    #       remote script has no `set -e` and ends in `true`,
    #       orphan_cleanup always reported success regardless — only the
    #       bin/dc line (plain -f, correctly written) ever matched
    #       anything. Likely explains some of the manual orphan-killing
    #       needed in earlier sessions instead of this function catching it.
    #   (2) Simply dropping '-E' reintroduces the OTHER bug class already
    #       fixed elsewhere in this file (bin/dc vs sbin/dcgm) and in
    #       lib/validate.sh (iperf3): an unbracketed 'mpirun|prterun|prted'
    #       is matched by pkill against the FULL remote command line,
    #       which literally contains that same text (twice — TERM and
    #       KILL lines are one combined ssh_root script) — self-kills the
    #       shell running this function (rc=255-class death, reproduced
    #       0/1 success before bracketing, 1/1 after). Bracketing one
    #       letter per alternative ('[m]pirun|[p]rterun|[p]rted') defeats
    #       the literal self-match while '[m]' etc. still matches the
    #       real single character as a regex — reproduced killing a real
    #       process named "mpirun ..." successfully after this fix.
    ssh_root "$h" "
      pkill -TERM -f '[.]/bin/dc' 2>/dev/null
      pkill -TERM -f '[m]pirun|[p]rterun|[p]rted' 2>/dev/null
      sleep 2
      pkill -KILL -f '[.]/bin/dc' 2>/dev/null
      pkill -KILL -f '[m]pirun|[p]rterun|[p]rted' 2>/dev/null
      true
    " 2>/dev/null || failed+=("$h")
  done
  if [ "${#failed[@]}" -gt 0 ]; then
    warn "orphan_cleanup: varredura falhou/inalcançável em: ${failed[*]} (pulado, não bloqueia)"
  fi
  # warn (not log) deliberately: inflight_resume calls orphan_cleanup and
  # its OWN stdout is captured via $(...) by the orchestrator
  # (resumed=$(inflight_resume)) — a log() line here would corrupt that
  # capture exactly like the run_ground_truth_check bug found empirically
  # 2026-07-15 (see 02-orchestrator.sh). Never confirmed to have actually
  # fired (no crash-resume had occurred as of 2026-07-15), but the same root
  # cause applies, so fixed proactively rather than waiting to observe it.
  warn "orphan_cleanup: varredura concluída em $(node_count) nó(s) vivo(s)"
}

# inflight_mark <experiment_id> <rep> <run_type> <result_dir> — written
# right BEFORE launching a run; cleared right after it terminates
# (success or failure) via inflight_clear. If the orchestrator process
# itself dies mid-run (frontend SSH drop, Ctrl-C, walltime expiry), this
# file survives on disk and is picked up by inflight_resume() on the next
# invocation.
inflight_mark() {
  local id=$1 rep=$2 run_type=$3 dir=$4
  printf '%s\t%s\t%s\t%s\n' "$id" "$rep" "$run_type" "$dir" > "$INFLIGHT_FILE"
}

inflight_clear() { rm -f "$INFLIGHT_FILE"; }

# inflight_resume — call ONCE at orchestrator startup, before the main
# loop, before nodes_liveness_probe (a crashed run may be the reason a
# node looks unreachable — sweep orphans while nodes() still reflects the
# PREVIOUS census, then let the caller re-probe fresh afterward).
#
# If an abandoned marker exists: runs orphan_cleanup (the crashed run may
# have left mpirun/dc processes holding GPUs on the very node(s) that were
# in flight), clears the marker, and prints the abandoned
# (id, rep, run_type, result_dir) tuple as TSV for the caller to act on.
# Deliberately does NOT call checkpoint_mark/checkpoint_integrity_ok
# itself: only the orchestrator has the CSV row context (expected_np,
# expected_dc_bytes for full runs) needed to judge the abandoned result
# correctly — this function's job ends at "here is what was interrupted,
# and the machines are now clean."
# Prints nothing and returns 1 if there was nothing to resume.
inflight_resume() {
  [ -s "$INFLIGHT_FILE" ] || return 1
  local id rep run_type dir
  IFS=$'\t' read -r id rep run_type dir < "$INFLIGHT_FILE"
  warn "inflight_resume: execução anterior do orquestrador foi interrompida em $id rep$rep ($run_type, $dir) — reconciliando"
  orphan_cleanup
  inflight_clear
  printf '%s\t%s\t%s\t%s\n' "$id" "$rep" "$run_type" "$dir"
  return 0
}
