#!/usr/bin/env bash
# run_netcal.sh -- collect Cornebize-style network calibration samples on two
# real chuc nodes (one rank each), for every requested link condition.
#
#   native  : no tc shaping, no UCX_TLS override -- the transport the
#             strong-scaling campaign actually used (lib/run.sh RUN_NATIVE=1)
#   <rate>  : tc-tbf shaping at <rate> + UCX_TLS=tcp,self,sm -- the transport
#             the bandwidth-sweep campaign and the simulations model
#             (lib/run.sh RUN_NATIVE=0)
#
# Usage (from anywhere, OAR_JOB_ID exported, bootstrap already done):
#   netcal/run_netcal.sh [budget_s_per_condition] [conditions...]
#   default: 120 native 25gbit 10gbit 1gbit
set -euo pipefail
NC_DIR=$(cd "$(dirname "$0")" && pwd)
BUDGET=${1:-120}
shift || true
CONDITIONS=("$@")
[ ${#CONDITIONS[@]} -gt 0 ] || CONDITIONS=(native 25gbit 10gbit 1gbit)

cd "$NC_DIR/../g5k"
source ./lib/core.sh
source ./conf/defaults.conf
source ./lib/shape.sh

require_nodes_file
mapfile -t NODE_ARR < <(nodes)
[ "${#NODE_ARR[@]}" -ge 2 ] || die "run_netcal.sh: need >=2 nodes"
NODE_A=${NODE_ARR[0]}
NODE_B=${NODE_ARR[1]}

OUT_DIR="$NC_DIR/results"
mkdir -p "$OUT_DIR"
HOSTFILE="$STATE_DIR/.hostfile_netcal"
printf '%s slots=1\n%s slots=1\n' "$NODE_A" "$NODE_B" > "$HOSTFILE"

log "netcal: building on $NODE_A"
node_script "$NODE_A" <<EOF
source $NIX_PROFILE
cd $PROJECT_DIR
nix develop --command bash -c "mpicc -O2 -o $NC_DIR/netcal $NC_DIR/netcal.c -lm"
EOF

for cond in "${CONDITIONS[@]}"; do
  stamp=$(date +%Y%m%dT%H%M%S)
  out="$OUT_DIR/netcal_${cond}_${stamp}.csv"
  if [ "$cond" = native ]; then
    shape_off
    ucx_env=":"; ucx_fwd=""; pml_mca=""
  elif [ "$cond" = native1rail ]; then
    # native, but UCX limited to ONE rendezvous rail: native measured ~45
    # Gbit/s on 25 Gbit/s ports (2026-10-02), suspected UCX multi-rail over
    # both chuc ports -- this condition tests that.
    shape_off
    ucx_env="export UCX_MAX_RNDV_RAILS=1"; ucx_fwd="-x UCX_MAX_RNDV_RAILS"; pml_mca=""
  else
    shape_apply "$cond"
    ucx_env="export UCX_TLS=tcp,self,sm; export UCX_NET_DEVICES=$KAVLAN_IFACE"
    ucx_fwd="-x UCX_TLS -x UCX_NET_DEVICES"
    pml_mca="--mca pml_ucx_tls tcp,self,sm"
  fi
  log "netcal: condition=$cond budget=${BUDGET}s nodes=$NODE_A,$NODE_B -> $out"
  node_script "$NODE_A" <<EOF > "$out.raw"
source $NIX_PROFILE
cd $PROJECT_DIR
nix develop --command bash -c '
  $ucx_env
  mpirun --allow-run-as-root --hostfile $HOSTFILE -np 2 --map-by node \
    --mca pml ucx $pml_mca $ucx_fwd \
    $NC_DIR/netcal $BUDGET 16777216 $RANDOM
'
EOF
  # nix develop prints build/warning noise on stdout; keep only CSV rows
  grep -E '^(op,size,duration_s|[a-z]+,[0-9]+,[0-9.e-]+)$' "$out.raw" > "$out"
  rm -f "$out.raw"
  {
    echo "condition=$cond"; echo "nodes=$NODE_A,$NODE_B"; echo "budget_s=$BUDGET"
    echo "date=$(date -Iseconds)"; echo "oar_job=${OAR_JOB_ID:-}"
    echo "shaping=$(current_shaping)"
  } > "$out.meta"
  log "netcal: $cond done ($(($(wc -l < "$out") - 1)) samples)"
done

shape_off
log "netcal: all conditions done"
