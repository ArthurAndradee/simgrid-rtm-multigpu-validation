# shellcheck shell=bash
# ---------------------------------------------------------------------------
# core.sh — base helpers shared by every lib/*.sh and scripts/*.sh.
#
# This is g5k/lib.sh (validated across two on-hardware sessions) moved here
# verbatim, plus a handful of small additions (JSON-ish escaping, version
# capture) needed by the new campaign framework. Nothing that already
# worked was changed.
# ---------------------------------------------------------------------------

: "${G5K_USER:=$USER}"
: "${G5K_HOME:=/home/$G5K_USER}"
: "${PROJECT_DIR:=$G5K_HOME/ic/io-research/distributed-cube-average}"
: "${G5K_DIR:=$PROJECT_DIR/g5k}"
: "${STATE_DIR:=$G5K_DIR/state}"
: "${CONF_DIR:=$G5K_DIR/conf}"
: "${CSV_DIR:=$G5K_DIR/csv}"
: "${RESULTS_DIR:=$G5K_DIR/results}"
: "${LOGS_DIR:=$G5K_DIR/logs}"
: "${CHECKPOINTS_DIR:=$G5K_DIR/checkpoints}"

: "${NODES_FILE:=$STATE_DIR/nodes.txt}"        # one primary hostname per line
: "${GPUS_FILE:=$STATE_DIR/gpus.txt}"          # "<host> <ngpus>" per line
: "${HOSTFILE_MPI:=$STATE_DIR/hostfile.mpi}"   # "<host> slots=<n>" (full census)
: "${NODES_ALIVE_FILE:=$STATE_DIR/nodes_alive.txt}"  # subset of NODES_FILE
                                                # confirmed reachable by the
                                                # most recent reactive
                                                # liveness probe (see
                                                # lib/resilience.sh). NEVER
                                                # written by anything other
                                                # than nodes_liveness_probe;
                                                # NODES_FILE itself (the
                                                # original allocation) is
                                                # never modified, so it
                                                # stays available for audit.

: "${DEPLOY_ENV:=debiannvopen11-big}"          # verified against `kaenv3 -l` on 2026-07-09 (site: lille).
                                                # "debian11-x64-big" does NOT exist on this site, and plain
                                                # "debian11-big" ships NO NVIDIA driver at all (nvidia-smi
                                                # would fail). debiannvopen11-big is the public G5K image
                                                # with NVIDIA open kernel modules preinstalled, suitable
                                                # for Ampere/A100.
: "${KAVLAN_IFACE:=ens15f1np1}"                # physical NIC moved into the kavlan
: "${KAVLAN_DNS_SUFFIX:=eth1}"                 # G5K DNS alias for that NIC
: "${CLUSTER_KEY:=$STATE_DIR/cluster_key}"     # root<->root key, job-scoped

NIX_PROFILE=/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
          -o ConnectTimeout=20 -o BatchMode=yes -o LogLevel=ERROR)

mkdir -p "$STATE_DIR" "$LOGS_DIR" "$CHECKPOINTS_DIR" "$RESULTS_DIR"

log()  { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '\033[1;33m[%s] WARN\033[0m %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# diary <text> — appends a timestamped line to the running campaign diary.
# Meant for methodology-section-ready notes: decisions, hypotheses, findings.
diary() {
  local f="$LOGS_DIR/diario_de_bordo.md"
  [ -f "$f" ] || printf '# Diário de bordo — campanha experimental\n\n' > "$f"
  printf -- '- **%s** — %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$f"
}

# nodes — the working node set. Prefers $NODES_ALIVE_FILE (written by
# nodes_liveness_probe, lib/resilience.sh) when it exists and is
# non-empty, falling back to the original $NODES_FILE otherwise. This is
# the ONLY place this preference is decided: node_count/head_node/
# csv_build_experiment_hostfile/all_nodes_script all derive from nodes(),
# so a reactive liveness re-probe automatically and immediately narrows
# every one of them without any other change (see design doc secao 8).
nodes() {
  if [ -s "$NODES_ALIVE_FILE" ]; then
    grep -v '^[[:space:]]*$' "$NODES_ALIVE_FILE"
  else
    grep -v '^[[:space:]]*$' "$NODES_FILE"
  fi
}
node_count() { nodes | wc -l; }
head_node()  { nodes | head -n 1; }

require_nodes_file() {
  [ -s "$NODES_FILE" ] || die "$NODES_FILE missing/empty — run scripts/01-bootstrap.sh first"
}

# ssh_root <host> [cmd...] — frontend user -> root@node (kadeploy key).
#
# -n (stdin from /dev/null) is REQUIRED here, not cosmetic. [EMP, found
# 2026-07-15 on the real allocation]: every ssh_root call site passes a
# self-contained command string and never needs to forward stdin: without
# -n, ssh inherits fd0 from whatever called ssh_root. When ssh_root is
# invoked from inside a `while read ...; done < <(some_command)` loop
# (e.g. the orchestrator's `while read -r topo nos gpus n vram; do ...
# done < <(csv_topology_representatives)`), ssh reads and discards the
# REST of that process substitution's remaining output as its own stdin
# — silently terminating the outer loop after the first row that reaches
# an ssh_root call. This exact bug caused the orchestrator's FULL phase to
# process only the first topology (1x2x2/N64) and silently never reach
# the rest (2x2x2/N1536 onward) — no error, no warning, just early exit.
# node_script is NOT given -n: its callers always provide their own stdin
# via heredoc (<<EOF ... EOF), which already fully replaces fd0 for that
# specific invocation, so it was never at risk.
ssh_root() {
  local host=$1; shift
  ssh -n "${SSH_OPTS[@]}" "root@$host" "$@"
}

# node_script <host> <<'EOF' ... EOF — run a bash script (stdin) on one node.
node_script() {
  local host=$1
  ssh "${SSH_OPTS[@]}" "root@$host" 'bash -s'
}

# all_nodes_script "<bash script>" [node1 node2 ...] — run the same script on
# every given node (default: all nodes in $NODES_FILE) in parallel, wait for
# all, fail (with the offending node's log) if any fails.
all_nodes_script() {
  local script=$1; shift
  local target_nodes=("$@")
  [ ${#target_nodes[@]} -eq 0 ] && mapfile -t target_nodes < <(nodes)
  local rc=0 pids=() hosts=()
  for h in "${target_nodes[@]}"; do
    printf '%s' "$script" | node_script "$h" >"$STATE_DIR/.log.$h.$$" 2>&1 &
    pids+=("$!"); hosts+=("$h")
  done
  local i
  for i in "${!pids[@]}"; do
    if ! wait "${pids[$i]}"; then
      rc=1
      echo "---------- FAILED on ${hosts[$i]} ----------" >&2
      cat "$STATE_DIR/.log.${hosts[$i]}.$$" >&2
    fi
  done
  rm -f "$STATE_DIR"/.log.*."$$"
  return "$rc"
}

# oar_walltime_remaining_s — seconds remaining in $OAR_JOB_ID's walltime,
# or empty (nonzero return, warning logged) if it cannot be determined.
# Requires OAR_JOB_ID to already be set by the operator — same convention
# as lib/deploy.sh's kavlan calls: this project never auto-detects it from
# job-shell environment, since the orchestrator runs from a plain frontend
# shell, not inside an interactive `oarsub -C` shell.
oar_walltime_remaining_s() {
  : "${OAR_JOB_ID:?oar_walltime_remaining_s: OAR_JOB_ID not set — export it before running the campaign (same convention as lib/deploy.sh)}"
  local info
  info=$(oarstat -f -j "$OAR_JOB_ID" 2>/dev/null) \
    || { warn "oar_walltime_remaining_s: oarstat failed for job $OAR_JOB_ID"; return 1; }
  local start_time walltime
  start_time=$(echo "$info" | sed -n 's/^ *start_time *= *//p' | head -1)
  walltime=$(echo "$info" | sed -n 's/^ *walltime *= *//p' | head -1)
  [ -n "$start_time" ] || { warn "oar_walltime_remaining_s: job $OAR_JOB_ID has no start_time (not running yet?)"; return 1; }
  [ -n "$walltime" ]   || { warn "oar_walltime_remaining_s: could not parse walltime for job $OAR_JOB_ID"; return 1; }
  local start_epoch
  start_epoch=$(date -d "$start_time" +%s 2>/dev/null) \
    || { warn "oar_walltime_remaining_s: could not parse start_time '$start_time'"; return 1; }
  local wh wm ws
  IFS=: read -r wh wm ws <<< "$walltime"
  local walltime_s=$(( 10#$wh*3600 + 10#$wm*60 + 10#${ws:-0} ))
  local now_epoch; now_epoch=$(date +%s)
  echo $(( start_epoch + walltime_s - now_epoch ))
}

# is_prime <n> — used to warn about MPI_Dims_create degenerating into slices.
is_prime() {
  local n=$1 i
  [ "$n" -lt 4 ] && return 0
  for ((i = 2; i * i <= n; i++)); do
    ((n % i == 0)) && return 1
  done
  return 0
}

# total_slots [hostfile] — sum of slots in a "<host> slots=<n>" file
# (defaults to the full-census $HOSTFILE_MPI).
total_slots() {
  awk -F'slots=' '{s += $2} END {print s+0}' "${1:-$HOSTFILE_MPI}"
}
