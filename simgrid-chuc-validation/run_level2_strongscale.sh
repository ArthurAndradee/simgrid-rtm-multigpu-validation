#!/usr/bin/env bash
# run_level2_strongscale.sh -- Level 2 simulation of every strong-scaling
# configuration (g5k/csv/strongscale_experiments.csv), with PER-TOPOLOGY
# compute constants (analysis/level2_compute_constants_strongscale.csv)
# instead of the original one-topology-per-node-count constants. The
# comparison target is the real strong-scaling run of the same experiment_id.
#
# Network calibration comes from a swappable file (default: the inherited
# poti/Cornebize values), so the same sweep can be re-run unchanged once the
# chuc recalibration (netcal/) exists:
#   CALIB=calibrations/<file>.cfg ./run_level2_strongscale.sh
#
# CPU only (BACKEND=simgrid, built into BUILDDIR=bin_simgrid_l2 -- NEVER into
# bin/, which holds the real campaign's CUDA binary on the shared NFS home).
# Runs configs in parallel; each smpirun is single-threaded.
#
# Usage (inside `nix develop`, from this directory):
#   ./run_level2_strongscale.sh [jobs=16] [np-filter e.g. "8 12"]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DIR/.." && pwd)"
JOBS=${1:-16}
NP_FILTER=${2:-}
CALIB=${CALIB:-$DIR/calibrations/poti_cornebize.cfg}
NET_BW=${NET_BW:-25Gbps}   # chuc NIC nominal rate (strong-scaling runs were unshaped)
CALIB_TAG=$(basename "$CALIB" .cfg)
RESULTS_DIR=${RESULTS_DIR:-$DIR/results_level2_strongscale/${CALIB_TAG}_${NET_BW}}
CONSTANTS=$REPO_ROOT/analysis/level2_compute_constants_strongscale.csv
PLAN=$REPO_ROOT/g5k/csv/strongscale_experiments.csv
BIN=$REPO_ROOT/bin_simgrid_l2/dc
[ -f "$CONSTANTS" ] || { echo "missing $CONSTANTS (run analysis/build_level2_compute_constants_strongscale.R)"; exit 1; }
mkdir -p "$RESULTS_DIR"

STENCIL=4; ABSORPTION=2
DX=1e-1; DY=1e-1; DZ=1e-1; DT=1e-6; TIME_MAX=1e-4

NET_LAT=$(sed -n 's/^NET_LAT=//p' "$CALIB")
mapfile -t CALIB_CFG < <(grep -E '^--cfg=' "$CALIB")
# Methodology flags (not calibration): identical to run_level2.sh, see its
# comments for why each one is needed.
METHOD_CFG=(
  --cfg=smpi/display-timing:yes
  --cfg=tracing/precision:9
  --cfg=smpi/shared-malloc:local
  --cfg=smpi/shared-malloc-blocksize:1073741824
  --cfg=smpi/simulate-computation:no
  --cfg=smpi/host-speed:1
)

echo "=== building bin_simgrid_l2/dc (BACKEND=simgrid) ==="
( cd "$REPO_ROOT" && make all BACKEND=simgrid BUILDDIR=bin_simgrid_l2 >/dev/null )

run_one() { # $1=experiment_id $2=np $3=dims_str $4=N
  local id=$1 np=$2 dims=$3 N=$4
  local run_dir="$RESULTS_DIR/$id"
  if grep -q '^\*,' "$run_dir/dc.output" 2>/dev/null; then echo "skip $id"; return 0; fi
  mkdir -p "$run_dir"
  local rpn=$(( np < 4 ? np : 4 )) nodes=$(( (np + 3) / 4 ))
  local size=$(( N - 2*STENCIL - 2*ABSORPTION ))
  lists() { awk -F, -v id="$id" -v col="$1" '
      NR==1 { for (i=1;i<=NF;i++) h[$i]=i; next }
      $h["experiment_id"]==id { v[$h["rank"]+0]=$h[col]; if ($h["rank"]+1>n) n=$h["rank"]+1 }
      END { for (r=0;r<n;r++) printf "%s%s", (r?",":""), v[r]; print "" }' "$CONSTANTS"; }
  local b i k
  b=$(lists mean_boundaries_s); i=$(lists mean_interior_s); k=$(lists mean_bookkeeping_s)
  PLATFORM_NUM_NODES=$nodes PLATFORM_RANKS_PER_NODE=$rpn PLATFORM_NET_BW=$NET_BW \
  PLATFORM_NET_LAT=$NET_LAT PLATFORM_HOSTFILE="$run_dir/hostfile.txt" \
  PLATFORM_XML_OUT="$run_dir/platform.xml" \
    python3 "$DIR/generate_platform_xml.py" > "$run_dir/platform_gen.log"
  ( cd "$run_dir" && rm -f dc.trace dc.csv dc.output
    DC_FIXED_BOUNDARIES_S="$b" DC_FIXED_INTERIOR_S="$i" DC_FIXED_BOOKKEEPING_S="$k" \
    timeout --kill-after=30 "${SIM_TIMEOUT_S:-3600}" \
    smpirun -platform platform.xml -hostfile hostfile.txt -np "$np" \
      "${METHOD_CFG[@]}" "${CALIB_CFG[@]}" \
      -trace --cfg=tracing/filename:dc.trace \
      "$BIN" --size-x=$size --size-y=$size --size-z=$size \
        --absorption=$ABSORPTION --dx=$DX --dy=$DY --dz=$DZ --dt=$DT --time-max=$TIME_MAX \
        --skip-output --topology="${dims//x/,}" > dc.output 2>&1
    [ -f dc.trace ] && pj_dump -z -l 9 dc.trace | grep ^State > dc.csv || true
    rm -f dc.trace )
  { echo "experiment_id: $id"; echo "np: $np topology: $dims nodes: $nodes ranks_per_node: $rpn"
    echo "net_bw: $NET_BW net_lat: $NET_LAT calibration: $CALIB"
    echo "compute_source: $CONSTANTS (per-topology, real A100, iteration>1)"
    echo "timestamp: $(date -Iseconds)"; } > "$run_dir/metadata.txt"
  if grep -q '^\*,' "$run_dir/dc.output"; then echo "done $id"; else echo "FAILED $id"; fi
}
export -f run_one
export RESULTS_DIR CONSTANTS STENCIL ABSORPTION DX DY DZ DT TIME_MAX NET_BW NET_LAT BIN DIR CALIB
export METHOD_CFG_STR="${METHOD_CFG[*]}" CALIB_CFG_STR="${CALIB_CFG[*]}"

# bash arrays don't survive export -f; rebuild them inside each worker.
tail -n +2 "$PLAN" | while IFS=, read -r id np dims N _; do
  [ -z "$NP_FILTER" ] || [[ " $NP_FILTER " == *" $np "* ]] || continue
  grep -q "^$id," "$CONSTANTS" || { echo "no constants for $id (not run on real hw yet) -- skip" >&2; continue; }
  echo "$id $np $dims $N"
done | xargs -P "$JOBS" -L 1 bash -c '
  read -r -a METHOD_CFG <<< "$METHOD_CFG_STR"; read -r -a CALIB_CFG <<< "$CALIB_CFG_STR"
  run_one "$@"' _

echo "=== results in $RESULTS_DIR ==="
