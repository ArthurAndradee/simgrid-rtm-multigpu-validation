# shellcheck shell=bash
# ---------------------------------------------------------------------------
# validate.sh — all pre-flight gates. Any failure here MUST abort the whole
# campaign (never continue partially), with a clear explanation of: cause,
# scientific impact, how to fix, which experiments are pending.
#
# Two tiers:
#   validate_campaign_preflight  — run ONCE before the campaign starts
#                                  (SSH, GPU policy, binary, MPI/CUDA/UCX smoke)
#   validate_before_batch        — run before EACH bandwidth batch
#                                  (tc applied correctly, disk space)
# ---------------------------------------------------------------------------

# validate_ssh_all — every node must be reachable and respond.
validate_ssh_all() {
  local h bad=()
  for h in $(nodes); do
    ssh_root "$h" true 2>/dev/null || bad+=("$h")
  done
  if [ "${#bad[@]}" -gt 0 ]; then
    die "SSH unreachable on: ${bad[*]}. Causa provável: nó não deployado, kavlan não configurado, ou chave root ausente. Corrigir: reexecutar scripts/01-bootstrap.sh."
  fi
  log "validate_ssh_all: OK (${#bad[@]} falhas em $(node_count) nós)"
}

# validate_gpu_policy — CAMPAIGN-LEVEL policy (distinct from the generic
# dynamic census in lib/setup.sh, which is unchanged and stays lenient for
# other uses). Records every node's real GPU count against
# EXPECTED_GPUS_PER_NODE. A mismatch no longer aborts the whole campaign
# (revised 2026-07-15 on the real allocation: chuc-3 reported 3/4 GPUs —
# a real GSP firmware fault on the 4th, confirmed against the G5K
# reference API, not a documented hardware difference or a transient
# census blip). experiments.csv's per-row Num_GPUs distribution DOES still
# assume EXPECTED_GPUS_PER_NODE uniformly, so a divergent node is not
# silently "adapted to" here — the actual safety net is
# csv_row_fits_gpu_capacity (lib/csv.sh), called per-row by the
# orchestrator BEFORE building any hostfile: rows whose uniform
# distribution would exceed a divergent node's real capacity are
# individually DEFERRED, never silently truncated (truncating would
# change RUN_NP vs. the real hostfile total, and worse, could shift
# MPI_Dims_create's decomposition away from the CSV's declared
# Topologia_MPI — see csv_row_fits_gpu_capacity's header comment).
validate_gpu_policy() {
  [ -s "$GPUS_FILE" ] || die "validate_gpu_policy: $GPUS_FILE missing — run lib/setup.sh:gpu_census first"
  local h n mismatches=0
  while read -r h n; do
    [ -z "$h" ] && continue
    if [ "$n" -eq "$EXPECTED_GPUS_PER_NODE" ]; then
      log "  Node $h — Esperado: $EXPECTED_GPUS_PER_NODE GPUs — Encontrado: $n GPUs — OK"
    else
      warn "  Node $h — Esperado: $EXPECTED_GPUS_PER_NODE GPUs — Encontrado: $n GPUs — DIVERGENTE"
      mismatches=$((mismatches + 1))
      diary "GPU divergente em $h: esperado $EXPECTED_GPUS_PER_NODE, encontrado $n. Linhas cuja distribuição uniforme exigir mais que $n neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente."
    fi
  done < "$GPUS_FILE"
  if [ "$mismatches" -gt 0 ]; then
    warn "validate_gpu_policy: $mismatches nó(s) com GPU divergente do esperado — campanha PROSSEGUE; linhas incompatíveis com a capacidade real de algum nó serão adiadas individualmente, não executadas de forma incorreta."
  else
    log "validate_gpu_policy: OK — todos os nós com exatamente $EXPECTED_GPUS_PER_NODE GPUs"
  fi
}

# validate_binary — bin/dc must exist and be executable; log its hash so
# scientific logs can prove which exact binary produced each result.
validate_binary() {
  [ -x "$PROJECT_DIR/bin/dc" ] || die "validate_binary: $PROJECT_DIR/bin/dc missing/not executable — run scripts/01-bootstrap.sh (build step)"
  DC_BINARY_SHA256=$(sha256sum "$PROJECT_DIR/bin/dc" | awk '{print $1}')
  log "validate_binary: OK (sha256=$DC_BINARY_SHA256)"
}

# validate_mpi_cuda_ucx_smoke — tiny single-node, 2-rank run to confirm
# mpirun/CUDA/OpenMPI/UCX are all actually functional before spending time
# on the real campaign. Uses the SAME launch path as lib/run.sh (native).
validate_mpi_cuda_ucx_smoke() {
  local head; head=$(head_node)
  log "validate_mpi_cuda_ucx_smoke: 2-rank smoke test on $head"
  local tmp_hostfile="$STATE_DIR/.smoke_hostfile"
  echo "$head slots=2" > "$tmp_hostfile"

  local RUN_HOSTFILE=$tmp_hostfile RUN_NP=2 RUN_NATIVE=1 \
        RUN_RESULT_DIR="$STATE_DIR/.smoke_result" \
        RUN_APP_ARGS=(--size-x=16 --size-y=16 --size-z=16 --absorption=2 \
                       --dx=1e-1 --dy=1e-1 --dz=1e-1 --dt=1e-6 --time-max=1e-4 \
                       --output-file=/tmp/g5k_smoke.dc)
  rm -rf "$STATE_DIR/.smoke_result"
  if ! run_experiment; then
    die "validate_mpi_cuda_ucx_smoke: smoke test failed — check $STATE_DIR/.smoke_result/dc.output. Causa provável: CUDA/UCX/OpenMPI mal configurado no ambiente Nix, ou nv-bridge ausente."
  fi
  grep -q "CUDA source using device" "$STATE_DIR/.smoke_result/dc.output" \
    || die "validate_mpi_cuda_ucx_smoke: dc.output has no 'CUDA source using device' line — CUDA path did not actually run."
  log "validate_mpi_cuda_ucx_smoke: OK"
}

# validate_disk_space <min_gb> — checks free space on the head node's NFS
# home (shared by all nodes) and on each node's local /tmp (Nix store).
validate_disk_space() {
  local min_gb=${1:-20}
  local head; head=$(head_node)
  local free_gb
  free_gb=$(ssh_root "$head" "df -BG --output=avail $PROJECT_DIR | tail -1 | tr -dc 0-9")
  [ "$free_gb" -ge "$min_gb" ] || die "validate_disk_space: only ${free_gb}GB free on NFS home (need >= ${min_gb}GB). Libere espaço em $RESULTS_DIR ou peça mais quota."
  log "validate_disk_space: OK (${free_gb}GB free on NFS home via $head)"
}

# validate_output_dir — results/ must exist and be writable.
validate_output_dir() {
  mkdir -p "$RESULTS_DIR"
  [ -w "$RESULTS_DIR" ] || die "validate_output_dir: $RESULTS_DIR not writable"
  log "validate_output_dir: OK ($RESULTS_DIR)"
}

# validate_disk_space_for_full <N> — checks free space against the EXACT
# expected .dc size for this specific full run (csv_expected_dc_bytes),
# not the generic 20GB/10GB floor from validate_disk_space (wildly
# insufficient for the largest full: N=2944 needs ~204GB). Design doc
# secao 9: without this, a full run could pass a generic preflight and
# then hit ENOSPC mid-write, which looks like a hang until diagnosed.
#
# UNLIKE every other validate_* in this file, this does NOT die() on
# failure: insufficient disk for ONE specific full run is a DEFER decision
# (retry this full later / next reservation), not a campaign-aborting
# condition — see design doc secao 5.3 (deferred/skipped are recomputed
# policy decisions, never persisted as failures). The caller (orchestrator)
# is responsible for treating a nonzero return as "defer", not "fail".
# Returns 0 (enough space) or 1 (not enough — caller should defer).
validate_disk_space_for_full() {
  local n=$1
  local expected_bytes; expected_bytes=$(csv_expected_dc_bytes "$n")
  local needed_gb
  needed_gb=$(awk -v b="$expected_bytes" 'BEGIN { printf "%.2f", (b/1e9)*1.10 }')
  local head; head=$(head_node)
  local free_gb
  free_gb=$(ssh_root "$head" "df -BG --output=avail $PROJECT_DIR | tail -1 | tr -dc 0-9")
  if awk -v free="$free_gb" -v need="$needed_gb" 'BEGIN { exit !(free>=need) }'; then
    log "validate_disk_space_for_full(N=$n): OK (${free_gb}GB livres >= ${needed_gb}GB necessarios [.dc esperado + 10% margem])"
    return 0
  fi
  warn "validate_disk_space_for_full(N=$n): INSUFICIENTE (${free_gb}GB livres < ${needed_gb}GB necessarios) — este full sera ADIADO, nao a campanha inteira"
  return 1
}

# validate_campaign_preflight — run ONCE, before the campaign loop starts.
validate_campaign_preflight() {
  require_nodes_file
  log "=== Pre-flight de campanha ==="
  validate_ssh_all
  gpu_census            # re-census: catch drift since bootstrap (node swap, GPU falling off the bus, etc.)
  validate_gpu_policy
  validate_binary
  validate_output_dir
  validate_disk_space 20
  validate_mpi_cuda_ucx_smoke
  csv_selfcheck
  log "=== Pre-flight OK — campanha pode prosseguir ==="
  diary "Pre-flight de campanha: OK. sha256(bin/dc)=$DC_BINARY_SHA256"
}

# validate_bandwidth_effective <expected_rate> — FUNCTIONAL check that tc
# tbf is actually constraining throughput to ~expected_rate, not just that
# a qdisc exists (the structural check right above this in
# validate_before_batch). Design doc secao 7 (closes SPOF-4 from the
# systemic audit): a run labeled "10gbit" that actually transfers at
# native speed (wrong interface, tc silently failed, kavlan renamed
# between reservations) would contaminate that whole bandwidth's masking
# metric with no visible error.
#
# Uses iperf3 bound EXPLICITLY to the kavlan IP of each node (not any IP),
# so the measurement crosses the SAME interface/qdisc the campaign's
# shaped MPI traffic uses. shape.sh's tbf is INTERFACE-WIDE (`tc qdisc add
# ... root ... tbf`, not htb/per-flow classes), so a bulk TCP iperf3
# stream is a valid proxy for "is this interface's egress actually
# throttled" — this equivalence holds ONLY while shape.sh's mechanism
# stays interface-wide; re-audit this function if that ever changes.
#
# [HIP, accepted residual — see design doc secao 7]: iperf3 measures a
# SUSTAINED bulk stream; the app's real halo traffic is SMALL and BURSTY.
# tbf's burst parameter (shape.sh: bps/8/500, ~2ms worth of bytes) was
# reasoned about for bursts but never empirically validated against the
# app's actual small-message pattern. This probe catches GROSS
# misconfiguration (shaping absent/wrong interface/very wrong rate), not
# fine behavioral equivalence between sustained and bursty traffic under
# tbf. If that finer equivalence ever needs proving, it requires a probe
# built from the app's own traffic pattern, not iperf3 — out of scope here.
#
# Tolerance band (0.5x-1.3x) is a GUESS, not yet calibrated — see design
# doc secao 7: the first real smoke test at 1/10/25gbit should record the
# achieved rate and refine this band from data.
#
# Fails CLOSED: any inability to run the probe itself (iperf3 missing,
# port blocked, JSON unparseable) dies the WHOLE campaign, same as an
# out-of-tolerance measurement — a probe that can't run must never be
# silently treated as "passed".
validate_bandwidth_effective() {
  local expected_rate=$1
  local -a nodes_list; mapfile -t nodes_list < <(nodes)
  if [ "${#nodes_list[@]}" -lt 2 ]; then
    log "validate_bandwidth_effective: só 1 nó disponível — sonda pulada (tráfego intra-nó nunca cruza a NIC shaped)"
    return 0
  fi

  local h1=${nodes_list[0]} h2=${nodes_list[1]}
  local kavlan_ips="$STATE_DIR/kavlan_ips.txt"
  [ -s "$kavlan_ips" ] || die "validate_bandwidth_effective: $kavlan_ips ausente/vazio — rode o deploy (lib/deploy.sh) primeiro"
  local ip1 ip2
  ip1=$(awk -v h="$h1" '$1==h{print $2}' "$kavlan_ips" | cut -d/ -f1)
  ip2=$(awk -v h="$h2" '$1==h{print $2}' "$kavlan_ips" | cut -d/ -f1)
  [ -n "$ip1" ] && [ -n "$ip2" ] \
    || die "validate_bandwidth_effective: IP kavlan não encontrado para $h1/$h2 em $kavlan_ips"

  local num unit expected_bps
  num=${expected_rate//[!0-9]/}; unit=${expected_rate//[0-9]/}
  case $unit in
    gbit) expected_bps=$((num * 1000000000)) ;;
    mbit) expected_bps=$((num * 1000000)) ;;
    kbit) expected_bps=$((num * 1000)) ;;
    *) die "validate_bandwidth_effective: unidade de taxa não suportada '$unit' em '$expected_rate'" ;;
  esac

  # Two SEPARATE ssh_root calls, deliberately not combined with ';' into
  # one command string. Two self-match bugs found empirically 2026-07-17
  # (job 2169626, chuc-3/4/8), same class as lib/resilience.sh's
  # orphan_cleanup ('[.]/bin/dc' vs 'sbin/dcgm'), neither caught before
  # because this function had only ever been mock-tested, never run on
  # real hardware until today:
  #   (1) pkill -f matches the FULL remote command line. An unbracketed
  #       'iperf3 -s' pattern matches its OWN invoking command line (the
  #       pattern argument itself contains that literal substring) and
  #       kills the shell running it, dropping the SSH session (rc=255,
  #       no output). Bracketing one letter ('[i]perf3 -s') defeats the
  #       literal self-match while the regex still matches real iperf3
  #       processes — reproduced 9/9 failures unbracketed, 0/0 after.
  #   (2) Less obvious: even bracketed, if pkill and the iperf3 launch
  #       stay on the SAME command line ("pkill ...; iperf3 -s ..."),
  #       pkill still matches the LATER, unbracketed "iperf3 -s" text of
  #       the launch command within that same line (pkill -f matches
  #       anywhere in the full cmdline, not just its own argument) —
  #       reproduced 5/5 failures combined-on-one-line even bracketed,
  #       0/3 failures once split into two separate ssh_root invocations
  #       (so pkill's own cmdline never contains the launch text at all).
  #   Also needed: setsid before iperf3 -D — -D alone forks but does not
  #   detach fast enough from the SSH session's process group; observed
  #   the daemon receiving a stray HUP ("iperf3: interrupt - the server
  #   has terminated" in its own logfile) right after ssh_root returned,
  #   before a client ever connected. setsid fixes this by starting the
  #   process in a new session immediately, not racing SSH's teardown.
  ssh_root "$h2" "pkill -f '[i]perf3' 2>/dev/null; true"
  ssh_root "$h2" "setsid iperf3 -s -1 -D -B $ip2 --logfile /tmp/g5k_iperf3_srv.log </dev/null >/dev/null 2>&1" \
    || die "validate_bandwidth_effective: falha ao iniciar servidor iperf3 em $h2 (iperf3 ausente na imagem de deploy? [HIP nao confirmado] — ver design doc secao 7)"
  sleep 1

  local result achieved_bps
  result=$(ssh_root "$h1" "iperf3 -c $ip2 -B $ip1 -t 3 -J" 2>/dev/null) \
    || die "validate_bandwidth_effective: iperf3 falhou entre $h1 e $h2 — abortando o lote inteiro (fail-closed: uma sonda que não roda não pode ser tratada como 'passou')."
  achieved_bps=$(echo "$result" | jq -r '.end.sum_received.bits_per_second' 2>/dev/null)
  [ -n "$achieved_bps" ] && [ "$achieved_bps" != "null" ] \
    || die "validate_bandwidth_effective: não foi possível extrair bits_per_second do JSON do iperf3 (saída: $result)"

  local ratio
  ratio=$(awk -v a="$achieved_bps" -v e="$expected_bps" 'BEGIN { printf "%.3f", a/e }')
  local achieved_gbit; achieved_gbit=$(awk -v a="$achieved_bps" 'BEGIN { printf "%.2f", a/1e9 }')
  if awk -v r="$ratio" 'BEGIN { exit !(r>=0.5 && r<=1.3) }'; then
    log "validate_bandwidth_effective($expected_rate): OK (medido=${achieved_gbit}Gbit/s entre $h1<->$h2, razão=${ratio})"
    return 0
  fi
  die "validate_bandwidth_effective: taxa medida (${achieved_gbit}Gbit/s) fora da tolerância [0.5x-1.3x] de $expected_rate entre $h1<->$h2 (razão=${ratio}). Causa provável: shape_apply falhou silenciosamente, interface kavlan errada, ou tc renomeou a interface entre reservas. Impacto científico: TODO o lote desta banda seria contaminado sem detecção. NÃO prosseguir até corrigir. tc qdisc em $h1: $(ssh_root "$h1" "tc qdisc show dev $KAVLAN_IFACE")"
}

# validate_before_batch <expected_rate> — before each bandwidth batch:
# confirm tc is actually applying the expected rate on every node
# (structural check) AND that it is actually constraining throughput
# (functional check, validate_bandwidth_effective).
validate_before_batch() {
  local expected=$1
  local applied; applied=$(current_shaping | awk '{print $1}')
  [ "$applied" = "$expected" ] || die "validate_before_batch: expected shaping '$expected' but current_shaping.txt says '$applied' — shape_apply may have failed silently."
  local h out
  for h in $(nodes); do
    out=$(ssh_root "$h" "tc qdisc show dev $KAVLAN_IFACE")
    echo "$out" | grep -q "tbf" || die "validate_before_batch: no tbf qdisc found on $h (got: $out)"
  done
  validate_bandwidth_effective "$expected"
  validate_disk_space 10
  log "validate_before_batch($expected): OK"
}
