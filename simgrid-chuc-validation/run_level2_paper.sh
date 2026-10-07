#!/usr/bin/env bash
# run_level2_paper.sh -- Level 2 of the 12 SSCAD-paper configurations
# (1-4 nodes x 1/10/25 Gbit/s, weak-scaling anchors N=1344/1728/1920/2176,
# MPI_Dims_create grids exactly as the real bandwidth-sweep campaign ran),
# for one or more NIC sharing policies (generate_platform_xml.py
# PLATFORM_NIC_SHARING): SHARED (every run before 2026-10-02) and
# SPLITDUPLEX (separate budget per direction), on identical inputs.
#
# Compute constants: analysis/level2_compute_constants.csv (one anchor
# topology per node count, same as the paper's Level 2). Network calibration:
# swappable file, default the inherited poti/Cornebize values.
#
# Memory: an smpirun here holds ~16 bytes/cell of real RAM (~14 GB at N=968,
# ~160 GB at N=2176), so sims are admitted one at a time, largest first, only
# when MemAvailable covers the estimate + RESERVE_MB. Run it on a dedicated
# node (chirop), never on the session/control node.
#
# Usage: ./run_level2_paper.sh [policies="SHARED SPLITDUPLEX"] [nodes="1 2 3 4"] [bands="1Gbps 10Gbps 25Gbps"]
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DIR/.." && pwd)"
POLICIES=${1:-"SHARED SPLITDUPLEX"}
NODES=${2:-"1 2 3 4"}
BANDS=${3:-"1Gbps 10Gbps 25Gbps"}
CALIB=${CALIB:-$DIR/calibrations/poti_cornebize.cfg}
CALIB_TAG=$(basename "$CALIB" .cfg)
: "${RESERVE_MB:=30000}"
: "${MAX_JOBS:=4}"
CONSTANTS=$REPO_ROOT/analysis/level2_compute_constants.csv
BIN=$REPO_ROOT/bin_simgrid_l2/dc
[ -f "$CONSTANTS" ] || { echo "missing $CONSTANTS"; exit 1; }

declare -A ANCHOR_N=( [1]=1344 [2]=1728 [3]=1920 [4]=2176 )
RANKS_PER_NODE=4
STENCIL=4; ABSORPTION=2
DX=1e-1; DY=1e-1; DZ=1e-1; DT=1e-6; TIME_MAX=1e-4

NET_LAT=$(sed -n 's/^NET_LAT=//p' "$CALIB")
mapfile -t CALIB_CFG < <(grep -E '^--cfg=' "$CALIB")
METHOD_CFG=(
  --cfg=smpi/display-timing:yes
  --cfg=tracing/precision:9
  --cfg=smpi/shared-malloc:local
  --cfg=smpi/shared-malloc-blocksize:1073741824
  --cfg=smpi/simulate-computation:no
  --cfg=smpi/host-speed:1
)

echo "=== $(date +%T) building bin_simgrid_l2/dc (BACKEND=simgrid) ==="
( cd "$REPO_ROOT" && make all BACKEND=simgrid BUILDDIR=bin_simgrid_l2 >/dev/null ) || { echo "build failed"; exit 1; }

fixed_list() { # $1=nodes $2=column -> "v0,v1,..." in rank order
  awk -F, -v nodes="$1" -v col="$2" '
    NR==1 { for (i=1;i<=NF;i++) h[$i]=i; next }
    $h["nodes"]==nodes { v[$h["rank"]+0]=$h[col]; if ($h["rank"]+1>n) n=$h["rank"]+1 }
    END { for (r=0;r<n;r++) printf "%s%s", (r?",":""), v[r]; print "" }' "$CONSTANTS"
}

run_one() { # $1=policy $2=nodes $3=band
  local policy=$1 nodes=$2 bw=$3 N=${ANCHOR_N[$2]}
  local run_dir="$DIR/results_level2_paper/${CALIB_TAG}_${policy}/${nodes}n_${bw}"
  mkdir -p "$run_dir"
  local size=$(( N - 2*STENCIL - 2*ABSORPTION )) np=$(( nodes * RANKS_PER_NODE ))
  PLATFORM_NUM_NODES=$nodes PLATFORM_RANKS_PER_NODE=$RANKS_PER_NODE PLATFORM_NET_BW=$bw \
  PLATFORM_NET_LAT=$NET_LAT PLATFORM_NIC_SHARING=$policy PLATFORM_HOSTFILE="$run_dir/hostfile.txt" \
  PLATFORM_XML_OUT="$run_dir/platform.xml" \
    python3 "$DIR/generate_platform_xml.py" > "$run_dir/platform_gen.log" 2>&1
  ( cd "$run_dir" && rm -f dc.trace dc.csv dc.output
    DC_FIXED_BOUNDARIES_S=$(fixed_list "$nodes" mean_boundaries_s) \
    DC_FIXED_INTERIOR_S=$(fixed_list "$nodes" mean_interior_s) \
    DC_FIXED_BOOKKEEPING_S=$(fixed_list "$nodes" mean_bookkeeping_s) \
    timeout --kill-after=60 "${SIM_TIMEOUT_S:-14400}" \
    smpirun -platform platform.xml -hostfile hostfile.txt -np "$np" \
      "${METHOD_CFG[@]}" "${CALIB_CFG[@]}" \
      -trace --cfg=tracing/filename:dc.trace \
      "$BIN" --size-x=$size --size-y=$size --size-z=$size \
        --absorption=$ABSORPTION --dx=$DX --dy=$DY --dz=$DZ --dt=$DT --time-max=$TIME_MAX \
        --skip-output > dc.output 2>&1
    [ -f dc.trace ] && pj_dump -z -l 9 dc.trace | grep ^State > dc.csv
    rm -f dc.trace )
  { echo "nodes: $nodes N: $N band: $bw nic_sharing: $policy"
    echo "calibration: $CALIB net_lat: $NET_LAT"
    echo "compute: $CONSTANTS (per node count, paper Level 2)"
    echo "simgrid: $(smpirun --version 2>&1 | head -1)"
    echo "timestamp: $(date -Iseconds)"; } > "$run_dir/metadata.txt"
  if grep -q '^\*,' "$run_dir/dc.output"; then echo "$(date +%T) done $policy ${nodes}n_$bw"
  else echo "$(date +%T) FAILED $policy ${nodes}n_$bw"; fi
}

# queue, largest N first so the big ones never wait behind small ones
queue=()
for nodes in $(echo $NODES | tr ' ' '\n' | sort -rn); do
  for policy in $POLICIES; do
    for bw in $BANDS; do
      d="$DIR/results_level2_paper/${CALIB_TAG}_${policy}/${nodes}n_${bw}"
      if grep -q '^\*,' "$d/dc.output" 2>/dev/null; then echo "skip $policy ${nodes}n_$bw"; continue; fi
      queue+=("$policy $nodes $bw")
    done
  done
done
# watchdog: if the estimate is ever wrong, kill the sims, not the node
( while :; do
    a=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
    [ "$a" -lt 15000 ] && { echo "$(date +%T) MEMORIA BAIXA (${a}MB) -- matando simulações"; pkill -TERM -f '[b]in_simgrid_l2/dc'; sleep 5; pkill -KILL -f '[b]in_simgrid_l2/dc'; }
    sleep 5
  done ) &
WATCHDOG=$!
trap 'kill $WATCHDOG 2>/dev/null' EXIT
echo "$(date +%T) ${#queue[@]} simulações na fila (RESERVE_MB=$RESERVE_MB MAX_JOBS=$MAX_JOBS)"

for item in "${queue[@]}"; do
  read -r policy nodes bw <<< "$item"
  N=${ANCHOR_N[$nodes]}
  need=$(( N * N / 1000 * N / 1000 * 16 * 12 / 10 ))   # MB: Mcells x 16 B + 20%
  while :; do
    avail=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
    running=$(jobs -rp | wc -l)
    [ "$running" -lt "$MAX_JOBS" ] && [ "$avail" -gt $(( need + RESERVE_MB )) ] && break
    [ "$running" -eq 0 ] && { echo "$(date +%T) ${nodes}n precisa ~${need}MB e só há ${avail}MB livres -- pulando"; continue 2; }
    sleep 10
  done
  echo "$(date +%T) start $policy ${nodes}n_$bw (N=$N, ~${need}MB, livre=${avail}MB)"
  run_one "$policy" "$nodes" "$bw" &
  sleep 60   # let the new sim reach its allocation peak before admitting the next
done
wait
echo "$(date +%T) fim"
