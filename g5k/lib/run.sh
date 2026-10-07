# shellcheck shell=bash
# ---------------------------------------------------------------------------
# run.sh — single mpirun launch + Akypuera/Pajé post-processing. Factored
# out of the validated g5k/05-run.sh, generalized to accept an explicit
# hostfile/np/result-dir (the orchestrator builds a DIFFERENT hostfile per
# experiment row, since Num_GPUs can be less than 4x Num_Nos — see
# lib/csv.sh) instead of always using the full-census hostfile.
#
# The UCX_TLS + --mca pml_ucx_tls fix below is byte-for-byte the validated,
# on-hardware-confirmed fix from session 2 (job 2165552, chuc-6/chuc-7,
# 2026-07-09/10). Do not remove --mca pml_ucx_tls: without it, forcing
# UCX_TLS=tcp,self,sm alone makes OpenMPI's pml_ucx component fail to
# initialize (see the long-form root-cause comment preserved in
# g5k/05-run.sh) because pml_ucx has its OWN transport allow-list
# (MCA param pml_ucx_tls, default IB/RDMA-only), independent of UCX_TLS.
# ---------------------------------------------------------------------------

# run_experiment — launch one mpirun invocation and post-process traces.
#
# Required environment (set by caller, e.g. lib/csv.sh + orchestrator):
#   RUN_HOSTFILE   path to a "<host> slots=<n>" file for THIS run only
#   RUN_NP         total rank count (must equal sum of RUN_HOSTFILE slots)
#   RUN_NATIVE     0 (shaped/TCP path, forces UCX_TLS+pml_ucx_tls) or
#                  1 (native: no UCX_TLS override, RDMA allowed)
#   RUN_RESULT_DIR output directory (created if missing)
#   RUN_APP_ARGS   array of ./bin/dc CLI arguments
# Optional:
#   RUN_TIMEOUT_S  seconds; if > 0, the mpirun invocation is wrapped in
#                  coreutils `timeout` (camada 1 of the watchdog design —
#                  see design doc secao 5.5. Camada 2, an external liveness
#                  watchdog distinguishing slow-finalization from deadlock,
#                  is deliberately deferred to a later phase). Computing
#                  the actual ceiling (min(T_est*k, walltime_restante-
#                  margem)) is the CALLER's job (the orchestrator, which
#                  has the CSV/topology context) — this function only
#                  applies whatever ceiling it is given, or none at all if
#                  unset/0 (backward-compatible default). Exit code 124
#                  means `timeout` killed the run — the caller is
#                  responsible for treating that as a distinct "timeout"
#                  outcome (not generic "failed") and for sweeping orphans
#                  afterward (a killed mpirun can leave per-rank dc
#                  processes on WORKER nodes, not just the head node this
#                  function launches from).
#
# Refuses to run --native while shaping is active (RDMA bypasses tc, so the
# combination would silently produce invalid data) — same guard as the
# validated g5k/05-run.sh.
run_experiment() {
  : "${RUN_HOSTFILE:?run_experiment: RUN_HOSTFILE not set}"
  : "${RUN_NP:?run_experiment: RUN_NP not set}"
  : "${RUN_NATIVE:?run_experiment: RUN_NATIVE not set}"
  : "${RUN_RESULT_DIR:?run_experiment: RUN_RESULT_DIR not set}"
  : "${RUN_TIMEOUT_S:=0}"
  [ "${#RUN_APP_ARGS[@]}" -gt 0 ] || die "run_experiment: RUN_APP_ARGS is empty"

  local shaping; shaping=$(current_shaping)
  if [ "$RUN_NATIVE" -eq 1 ] && [ "$shaping" != "off" ]; then
    die "RUN_NATIVE=1 with active shaping ($shaping): RDMA bypasses tc; call shape_off first"
  fi

  local timeout_prefix=""
  if [ "$RUN_TIMEOUT_S" -gt 0 ]; then
    # --kill-after gives a slow-to-terminate mpirun 30s to react to TERM
    # before being sent KILL — mirrors the two-step TERM-then-KILL
    # convention already used by orphan_cleanup (lib/resilience.sh).
    timeout_prefix="timeout --signal=TERM --kill-after=30 $RUN_TIMEOUT_S "
  fi

  local ucx_env ucx_fwd pml_ucx_tls_mca
  if [ "$RUN_NATIVE" -eq 0 ]; then
    # See header comment / g5k/05-run.sh for the full root-cause writeup.
    ucx_env="export UCX_TLS=tcp,self,sm
export UCX_NET_DEVICES=$KAVLAN_IFACE"
    ucx_fwd="-x UCX_TLS -x UCX_NET_DEVICES"
    pml_ucx_tls_mca="--mca pml_ucx_tls tcp,self,sm"
  else
    ucx_env=":"
    ucx_fwd=""
    pml_ucx_tls_mca=""
  fi

  mkdir -p "$RUN_RESULT_DIR"
  local head; head=$(head_node)

  log "np=$RUN_NP native=$RUN_NATIVE shaping=$shaping timeout=${RUN_TIMEOUT_S}s -> $RUN_RESULT_DIR"
  cp "$RUN_HOSTFILE" "$RUN_RESULT_DIR/hostfile.mpi"

  # timeout wraps the WHOLE `nix develop` invocation (not just the inner
  # mpirun line) so it does not depend on coreutils being importable
  # inside the nix-shell PATH — `timeout` itself only needs to exist on
  # the head node's base OS (standard on debiannvopen11-big).
  node_script "$head" <<EOF
set -e
source $NIX_PROFILE
cd $PROJECT_DIR
rm -f rastro-*.rst dc.trace dc.csv
$ucx_env
export RST_BUFFER_SIZE=$RST_BUFFER_SIZE
export LD_LIBRARY_PATH=/tmp/nv-bridge:\${LD_LIBRARY_PATH:-}
${timeout_prefix}nix develop --command bash -c '
  set -e -o pipefail
  export LD_LIBRARY_PATH=/tmp/nv-bridge:\$LD_LIBRARY_PATH
  mpirun --allow-run-as-root \\
    -np $RUN_NP \\
    --hostfile $RUN_HOSTFILE \\
    --map-by $MPI_MAP_BY \\
    --bind-to $MPI_BIND_TO \\
    --mca pml ucx $pml_ucx_tls_mca \\
    -x PATH -x LD_LIBRARY_PATH -x RST_BUFFER_SIZE $ucx_fwd \\
    ./bin/dc ${RUN_APP_ARGS[*]} 2>&1 | tee dc.output
  if ls rastro-*.rst >/dev/null 2>&1; then
    # Poll for all $RUN_NP rastro-*.rst files to become visible on the head
    # node before converting. mpirun returning only means every rank called
    # MPI_Finalize; it does not guarantee an NFS-mounted PROJECT_DIR has
    # propagated close-to-open visibility of files a REMOTE rank just wrote
    # to the head node ls glob run immediately after -- observed empirically
    # as an intermittent "found N rastro-*.rst, expected \$RUN_NP" integrity
    # failure (checkpoint.sh), more frequent with more physical nodes
    # involved (more chances for one remote write to lag). 15s cap: this is
    # a real, working NFS mount under normal load, so any genuine
    # completeness gap resolves in well under a second in practice; the cap
    # only bounds the pathological case, after which we fall through and
    # let the existing rastro-count integrity check catch it as before.
    for _ in \$(seq 1 30); do
      [ \$(ls rastro-*.rst 2>/dev/null | wc -l) -ge $RUN_NP ] && break
      sleep 0.5
    done
    # -l/--no-links: skip converting point-to-point LINK events. Real,
    # independent per-machine clocks across distinct physical hosts
    # occasionally record a send/receive pair with an apparent causality
    # inversion from clock skew, which aky_converter cannot correct without
    # a rastro_timesync sync file (not packaged here) -- this is exactly
    # where that skew-triggered mismatch lives. The fidelity/checkpoint
    # pipeline only reads State rows (MPI_Irecv/MPI_Waitall), never Link
    # rows, so -l loses nothing used. Same root cause and fix as the
    # reduced-N runs of simgrid-chuc-validation (LEVEL2_FINDINGS.md sec 6.6), confirmed here
    # 2026-09-03 against cross-node strong-scaling runs (job
    # 2199346/2199465).
    aky_converter -l rastro-*.rst > dc.trace
    pj_dump -z -l 9 dc.trace | grep ^State > dc.csv || true
  fi
'
EOF
  local rc=$?

  if [ "$rc" -eq 124 ]; then
    warn "run_experiment: TIMEOUT após ${RUN_TIMEOUT_S}s — run morto por 'timeout' (camada 1). Caller deve tratar como estado 'timeout' distinto e varrer órfãos (lib/resilience.sh:orphan_cleanup) em TODOS os nós do hostfile, não só $head."
  fi

  mv -f "$PROJECT_DIR"/rastro-*.rst "$RUN_RESULT_DIR"/ 2>/dev/null || true
  local f
  for f in dc.trace dc.csv dc.output; do
    [ -f "$PROJECT_DIR/$f" ] && mv -f "$PROJECT_DIR/$f" "$RUN_RESULT_DIR/"
  done

  return "$rc"
}
