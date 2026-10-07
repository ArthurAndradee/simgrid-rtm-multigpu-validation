#!/usr/bin/env bash
# scripts/05-session-plan.sh -- one-shot plan for a single chuc allocation
# that closes as many pending items as possible, in priority order, adapting
# to whatever walltime is actually left:
#
#   0. bootstrap (deploy + setup + build + preflight), one automatic retry
#   1. Idea 1: strong-scaling rows of NP_TARGET (default 24) -- the item that
#      needs the most nodes, i.e. the scarcest resource, so it goes first.
#      It stops starting new reps when only IDEA2_RESERVE_S of walltime is
#      left, so step 2 always gets its slot; whatever is left is resumable.
#   2. Idea 2: network calibration samples (netcal/run_netcal.sh), then
#      repeated NIC-contention microbenchmarks. Only needs 2 nodes, so it is
#      the part that is cheap to redo on a later, smaller allocation.
#   3. cleanup: shaping off, orphan sweep.
#
# If fewer nodes than NP_TARGET/4 come up, step 1 is skipped and step 2 gets
# the whole window.
#
# Runs on the FRONTEND. Usage:
#   nohup ./scripts/05-session-plan.sh <OAR_JOB_ID> > logs/session_<job>.log 2>&1 &
set -uo pipefail
cd "$(dirname "$0")/.."   # -> g5k/
export OAR_JOB_ID=${1:?usage: 05-session-plan.sh <OAR_JOB_ID>}
: "${NP_TARGET:=24}"
: "${IDEA2_RESERVE_S:=1080}"     # 18 min kept for step 2 + cleanup
: "${CLEANUP_RESERVE_S:=180}"
source ./lib/core.sh
source ./conf/defaults.conf

remaining() { oar_walltime_remaining_s 2>/dev/null || echo 0; }
stamp() { log "== $* (walltime restante: $(remaining)s) =="; }

# --- node file (OAR_NODE_FILE is not set outside an oarsub -C shell) -----
hosts=$(oarstat -f -j "$OAR_JOB_ID" | sed -n 's/^ *assigned_hostnames = //p' | tr '+' '\n')
[ -n "$hosts" ] || die "job $OAR_JOB_ID has no assigned hosts (not running yet?)"
mkdir -p "$HOME/oar_node_files"
export OAR_NODE_FILE="$HOME/oar_node_files/$OAR_JOB_ID"
echo "$hosts" > "$OAR_NODE_FILE"
rm -f "$NODES_ALIVE_FILE"   # stale file from a previous job broke bootstrap twice
stamp "Job $OAR_JOB_ID: $(echo "$hosts" | wc -l) nós: $(echo "$hosts" | paste -sd' ')"

# --- 0. bootstrap -------------------------------------------------------
stamp "0. bootstrap"
if ! ./scripts/01-bootstrap.sh; then
  warn "bootstrap falhou -- nova tentativa completa"
  rm -f "$NODES_ALIVE_FILE"
  ./scripts/01-bootstrap.sh || die "bootstrap falhou duas vezes -- intervenção manual"
fi

# --- 1. Idea 1: np=NP_TARGET --------------------------------------------
avail=$(node_count)
if [ $((avail * EXPECTED_GPUS_PER_NODE)) -ge "$NP_TARGET" ]; then
  # The orchestrator marks a rep 'failed' and moves on (e.g. the intermittent
  # Akypuera trace-conversion failure, diario 2026-07-17), and only retries it
  # on its NEXT invocation -- so re-run it while failures remain and the
  # walltime guard still lets reps start. Done reps are skipped on re-runs.
  for pass in 1 2 3; do
    stamp "1. strong scaling np=$NP_TARGET ($avail nós), passada $pass"
    if MIN_WALLTIME_MARGIN_S=$IDEA2_RESERVE_S ./scripts/03-strongscale-orchestrator.sh --np "$NP_TARGET"; then
      break
    fi
    warn "passada $pass terminou com falhas -- retentando as que faltam"
    [ $(( $(remaining) - IDEA2_RESERVE_S )) -gt 300 ] || { warn "sem tempo para nova passada (retomável)"; break; }
  done
else
  warn "só $avail nós -- np=$NP_TARGET impossível, pulando direto para a Ideia 2"
fi

# --- 2. Idea 2 ------------------------------------------------------------
# netcal: 4 conditions, each ~budget + ~40s overhead; give it at most 60% of
# what is left for step 2, capped at 150s per condition.
left=$(( $(remaining) - CLEANUP_RESERVE_S ))
if [ "$left" -gt 300 ]; then
  budget=$(( (left * 60 / 100) / 4 - 40 ))
  [ "$budget" -gt 150 ] && budget=150
  [ "$budget" -lt 30 ] && budget=30
  stamp "2a. calibração de rede (netcal), ${budget}s por condição"
  # netcal has never run on chuc yet: hard cap so a hang cannot eat the
  # microbench slot and the cleanup (budget + ~60s overhead per condition).
  timeout --kill-after=30 $(( 4 * (budget + 60) + 120 )) \
    ../netcal/run_netcal.sh "$budget" native 25gbit 10gbit 1gbit || warn "netcal falhou/expirou"
else
  warn "sem tempo para netcal (${left}s)"
fi

stamp "2b. microbenchmark de contenção de NIC (repetições)"
for rate in 1gbit 10gbit 25gbit 1gbit 10gbit 25gbit 1gbit; do
  [ $(( $(remaining) - CLEANUP_RESERVE_S )) -gt 330 ] || { warn "tempo esgotado para microbench"; break; }
  timeout --kill-after=30 300 ../nic_contention_benchmark/run_microbench.sh "$rate" || warn "microbench $rate falhou/expirou"
done

# --- 3. cleanup -------------------------------------------------------------
stamp "3. limpeza"
source ./lib/shape.sh
source ./lib/resilience.sh
source ./lib/checkpoint.sh
shape_off || true
orphan_cleanup || true
stamp "fim do plano"
checkpoint_summary 2>/dev/null || true
