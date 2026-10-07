#!/usr/bin/env bash
# run_microbench.sh — runs microbench.c on 2 real chuc nodes (4 senders on
# node A, 4 matched receivers on node B), under the EXACT same tc-tbf
# shaping + UCX_TLS forcing the real bandwidth-shaped campaign uses
# (g5k/lib/shape.sh, g5k/lib/run.sh RUN_NATIVE=0 path), so this is a direct
# probe of Hypothesis 2 in LEVEL2_FINDINGS.md sec 6.7 -- not a from-scratch
# reimplementation of the shaping/launch mechanism.
#
# Usage (inside an OAR deploy+kavlan job, OAR_JOB_ID exported, >=2 nodes):
#   cd g5k && ./scripts/../../nic_contention_benchmark/run_microbench.sh [rate]
# rate defaults to 1gbit (the condition under investigation); pass 10gbit or
# 25gbit to confirm the effect vanishes there too (sec 6.7: "only shows up
# at 1Gbit/s" is part of the H2 argument, worth re-checking directly).
set -euo pipefail
RATE=${1:-1gbit}

# MB_DIR must be resolved BEFORE the `cd` below: dirname "$0" is a pure
# string operation on argv[0], so if $0 is relative (e.g. "./run_microbench.sh"),
# resolving it via `cd ... && pwd` AFTER changing into g5k/ silently lands
# back in g5k/ instead of nic_contention_benchmark/ -- found 2026-09-01,
# job 2198777: mpicc failed with "g5k/microbench.c: No such file or directory".
MB_DIR=$(cd "$(dirname "$0")" && pwd)

cd "$(dirname "$0")/../g5k"
source ./lib/core.sh
source ./conf/defaults.conf
source ./lib/shape.sh

RANKS_PER_NODE=4
OUT_DIR="$MB_DIR/results"
mkdir -p "$OUT_DIR"
STAMP=$(date +%Y%m%dT%H%M%S)
OUT_CSV="$OUT_DIR/microbench_${RATE}_${STAMP}.csv"

require_nodes_file
mapfile -t NODE_ARR < <(nodes)
[ "${#NODE_ARR[@]}" -ge 2 ] || die "run_microbench.sh: need >=2 nodes, got ${#NODE_ARR[@]}"
NODE_A=${NODE_ARR[0]}
NODE_B=${NODE_ARR[1]}
log "microbench: node A (senders) = $NODE_A, node B (receivers) = $NODE_B, rate=$RATE"

HOSTFILE="$STATE_DIR/.hostfile_microbench"
{
  echo "$NODE_A slots=$RANKS_PER_NODE"
  echo "$NODE_B slots=$RANKS_PER_NODE"
} > "$HOSTFILE"

log "microbench: building microbench.c inside nix develop on $NODE_A"
node_script "$NODE_A" <<EOF
source $NIX_PROFILE
cd $PROJECT_DIR
nix develop --command bash -c "mpicc -O2 -o $MB_DIR/microbench $MB_DIR/microbench.c"
EOF

log "microbench: applying tc shaping ($RATE) on all nodes"
shape_apply "$RATE"

log "microbench: running (UCX_TLS=tcp,self,sm, same as the real campaign's shaped path)"
node_script "$NODE_A" <<EOF > "$OUT_CSV"
source $NIX_PROFILE
cd $PROJECT_DIR
nix develop --command bash -c '
  export UCX_TLS=tcp,self,sm
  export UCX_NET_DEVICES=$KAVLAN_IFACE
  mpirun --allow-run-as-root \
    --hostfile $HOSTFILE \
    -np $((RANKS_PER_NODE * 2)) \
    --map-by slot \
    --mca pml_ucx_tls tcp,self,sm \
    -x UCX_TLS -x UCX_NET_DEVICES \
    $MB_DIR/microbench
'
EOF

log "microbench: removing shaping"
shape_off

log "microbench: done -> $OUT_CSV"
wc -l "$OUT_CSV"
