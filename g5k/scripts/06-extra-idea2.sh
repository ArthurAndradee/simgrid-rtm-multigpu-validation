#!/usr/bin/env bash
# scripts/06-extra-idea2.sh -- extra Idea 2 measurements for leftover
# walltime after 05-session-plan.sh finished (job 2216790 ended its plan with
# ~40 min left):
#   1. record which UCX devices the nodes expose (ucx_info -d)
#   2. netcal native1rail -- native with UCX_MAX_RNDV_RAILS=1
#   3. more NIC-contention microbench repeats
#   4. cleanup
# Every step is time-guarded; cleanup always runs.
#
# Usage (frontend, from g5k/):
#   nohup ./scripts/06-extra-idea2.sh <OAR_JOB_ID> [microbench_reps_per_rate=10] > logs/extra_<job>.log 2>&1 &
set -uo pipefail
cd "$(dirname "$0")/.."   # -> g5k/
export OAR_JOB_ID=${1:?usage: 06-extra-idea2.sh <OAR_JOB_ID> [reps]}
REPS=${2:-10}
: "${CLEANUP_RESERVE_S:=300}"
source ./lib/core.sh
source ./conf/defaults.conf
source ./lib/shape.sh
source ./lib/resilience.sh
trap 'shape_off >/dev/null 2>&1 || true' EXIT

remaining() { oar_walltime_remaining_s 2>/dev/null || echo 0; }
stamp() { log "== $* (walltime restante: $(remaining)s) =="; }
require_nodes_file

stamp "1. dispositivos UCX em $(head_node)"
node_script "$(head_node)" <<EOF | grep -E 'Transport|Device|bandwidth' | head -60 > ../netcal/results/ucx_devices_$(date +%Y%m%dT%H%M%S).txt
source $NIX_PROFILE
cd $PROJECT_DIR
nix develop --command bash -c 'ucx_info -d'
EOF
log "ucx_info salvo em netcal/results/"

if [ $(( $(remaining) - CLEANUP_RESERVE_S )) -gt 400 ]; then
  stamp "2. netcal native1rail (90s)"
  timeout --kill-after=30 300 ../netcal/run_netcal.sh 90 native1rail || warn "netcal native1rail falhou/expirou"
fi

stamp "3. microbench: $REPS repetições por taxa"
for i in $(seq 1 "$REPS"); do
  for rate in 1gbit 10gbit 25gbit; do
    [ $(( $(remaining) - CLEANUP_RESERVE_S )) -gt 120 ] || { warn "tempo esgotado no microbench (rep $i)"; break 2; }
    timeout --kill-after=30 120 ../nic_contention_benchmark/run_microbench.sh "$rate" >/dev/null || warn "microbench $rate rep $i falhou/expirou"
  done
done

stamp "4. limpeza"
shape_off || true
orphan_cleanup || true
stamp "fim do bloco extra"
