#!/usr/bin/env bash
# run_level2.sh — Level 2: same shared-NIC platform + ORIGINAL poti/Cornebize
# network calibration as run_validation.sh (Level 1 / Option C), but with the
# CUDA compute side replaced by a FIXED, per-rank, per-topology constant
# extracted from the real campaign's own traces (already collected, no new
# benchmark run -- see analysis/extract_kernel_time.R and
# analysis/build_level2_compute_constants.R for how and why).
#
# WHY THIS EXISTS: SMPI's online kernel-time sampling (src/worker.c's
# sampled_computation()) has no static/portable "compute model" to swap a
# number into -- it always measures the real wall time of the CUDA kernel on
# whichever machine executes the simulation. There is no stored RTX4070
# baseline either (the original poti simulation's own trace was never
# archived). So "update only the compute component, keep the original
# network model" cannot be done by editing a config parameter; it requires
# bypassing the online sampling with a real, already-measured value. See
# src/worker.c's DC_FIXED_BOUNDARIES_S / DC_FIXED_INTERIOR_S env vars
# (added 2026-08-12, guarded by #ifdef SIMGRID, inert unless set -- BACKEND=
# cuda, the real campaign, never reads them).
#
# BECAUSE compute is now a fixed constant (no real kernel launch happens at
# all when these env vars are set), this script builds with BACKEND=simgrid
# (CPU/OpenMP sources, never actually invoked) instead of BACKEND=
# simgrid_cuda -- no GPU, no CUDA toolkit, no chuc allocation needed. Runs
# entirely on any machine with smpicc/smpirun (SimGrid) available.
#
# Usage: ./run_level2.sh [node-count list, default 1,2,3,4]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DIR/.." && pwd)"
cd "$REPO_ROOT"

RESULTS_DIR="$DIR/results_level2"
mkdir -p "$RESULTS_DIR"

CONSTANTS_CSV="$REPO_ROOT/analysis/level2_compute_constants.csv"
[ -f "$CONSTANTS_CSV" ] || { echo "Missing $CONSTANTS_CSV -- run analysis/build_level2_compute_constants.R first"; exit 1; }

NODE_LIST="${1:-1,2,3,4}"
IFS=',' read -r -a NODES_TO_RUN <<< "$NODE_LIST"

SECONDS=0
log_elapsed() { echo "    [t=+${SECONDS}s elapsed since script start]"; }

STENCIL=4
ABSORPTION=2
DX=1e-1
DY=1e-1
DZ=1e-1
DT=1e-6
TIME_MAX=1e-4

cuda_size() { echo $(( $1 - 2*STENCIL - 2*ABSORPTION )); }

declare -A ANCHOR_N=( [1]=1344 [2]=1728 [3]=1920 [4]=2176 )
RANKS_PER_NODE=4
BANDWIDTHS=(1Gbps 10Gbps 25Gbps)
NET_LAT="22.7us" # reused unchanged from original poti calibration, same as Level 1

# Identical to run_validation.sh's SMPI_CFG_COMMON, minus the
# smpi/privatization:no workaround (not needed here -- BACKEND=simgrid's
# smpicc-built bin/dc links fine and dlopen-loads fine, confirmed by a local
# smoke test 2026-08-12; the dlopen bug that blocks Level 1 is specific to
# the simgrid_cuda/CUDA-runtime link, which this backend never touches).
SMPI_CFG_COMMON=(
  --cfg=smpi/display-timing:yes
  # precision/timing:1e-9 (present in run_validation.sh's SMPI_CFG_COMMON,
  # SimGrid 4.1) dropped here: SimGrid 3.25 (the version available locally,
  # see run_level2.sh header) does not register that config key at all --
  # smpirun aborts inside simgrid::config::set_parse trying to set it
  # (confirmed live, bisected flag-by-flag, 2026-08-12). It is a numerical
  # simulation-precision knob, NOT one of the Cornebize calibration
  # parameters below, so dropping it does not touch the calibration itself
  # -- 3.25's default precision applies instead.
  --cfg=tracing/precision:9
  # "local" (SimGrid's default sharing granularity, per-allocation-size
  # bucket), NOT "global" (one shared backing for literally everything):
  # tried both live, 2026-08-13. "global" was catastrophically slow with
  # this app (5+ min, zero ranks finished init) despite an isolated
  # alloc+memset microbenchmark showing only ~2x overhead -- root cause
  # never isolated. "local" tested fast in the same microbenchmark (25s,
  # actually faster than plain malloc's 34s) and is what's used here.
  --cfg=smpi/shared-malloc:local
  # shared-malloc-blocksize raised from SMPI's 1MB default: it "folds" each
  # SMPI_SHARED_MALLOC'd array into (size/blocksize) separate mmap regions,
  # and with ~20 large (up to ~16GB) per-rank arrays x up to 16 ranks in one
  # process (see src/worker.c's DC_MALLOC), the 1MB default blew through
  # this system's vm.max_map_count (65530, the standard Linux default --
  # confirmed live, 2026-08-12: "Could not map folded virtual memory" after
  # ~16GB into the 4-node/16-rank run). 1GB blocks keep the per-allocation
  # mapping count in the low tens even for the largest arrays, comfortably
  # under the limit, without giving up any of the real physical-memory
  # savings (still backed by a handful of physical pages either way).
  --cfg=smpi/shared-malloc-blocksize:1073741824
  # DISABLE SMPI's automatic host-computation timing (default ON, confirmed
  # via smpirun --cfg=help:simulate-computation, 2026-08-13). With it on,
  # SMPI auto-times EVERY unwrapped host code path (halo insert loops, the
  # propagate kernel when not bypassed, etc.) and charges real wall-clock
  # time into the simulated clock -- which made results depend on memory-
  # backing implementation details (shared-malloc's cache-friendly "folded"
  # pages ran that code unrealistically fast vs plain malloc), not just on
  # the physics we intend to model. With it off, ONLY the three explicit
  # smpi_execute_benched() injection points in src/worker.c
  # (DC_FIXED_BOUNDARIES_S / DC_FIXED_INTERIOR_S / DC_FIXED_BOOKKEEPING_S,
  # all populated below from real-campaign-extracted constants) contribute
  # to simulated time, making the malloc-vs-shared-malloc choice a true
  # implementation detail again, with zero effect on results. Validated by
  # re-running 1-node with both and confirming identical throughput.
  --cfg=smpi/simulate-computation:no
  --cfg=smpi/host-speed:1
  --cfg=smpi/os:"0:4.17e-07:9.3e-08;2:1.2688358242159313e-06:5.509165162627468e-11;846:1.2427927374751976e-06:7.629724927795766e-11;1182:1.01878039474522e-06:2.2976714190789488e-10;6687:7.212526152845653e-07:2.3548673558712826e-10;65480:0.0:0.0"
  --cfg=smpi/or:"0:1.074e-06:6.000000000000027e-09;2:1.0473771622457872e-06:1.5567156532620197e-10;846:1.2421788110402576e-06:7.174648137343064e-43;1182:1.6995035871937564e-06:1.348689114201127e-10;6687:1.758151339164401e-06:1.1446056239417835e-10;65480:0.0:0.0"
  --cfg=smpi/ois:"0:4.99e-07:6.2e-08;2:5.71513825856767e-07:3.681266485442063e-11;846:1.3753277297356838e-07:3.538717583470924e-10;1182:2.0886700989740583e-07:1.9666759173075344e-10;6687:2.938735877055719e-39:1.105170449896893e-10;65480:5.548287028763466e-07:1.5407086056396026e-13"
  --cfg=smpi/bw-factor:"0:1.0;2:0.4510053758462671;846:0.5091684623185814;1182:0.948984644166369;6687:0.9193943188688236;65480:0.9412414252627215"
  --cfg=smpi/lat-factor:"0:0.837740263193759;2:0.790246085987436;846:1.0647374762712742;1182:1.4653793019194907;6687:1.394904217619273;65480:4.25253968678777"
  --cfg=smpi/iprobe:"1.6269591164444444e-07"
  --cfg=smpi/test:"1.4119688221333333e-07"
  --cfg=smpi/async-small-thresh:"65480"
  --cfg=smpi/send-is-detached-thresh:"65480"
)

echo "=== [t=+${SECONDS}s] Building dc (BACKEND=simgrid) ==="
make all BACKEND=simgrid
log_elapsed

# XML platform (generate_platform_xml.py), NOT the compiled S4U .so
# (compile_platform.sh / platform_shared_nic.cpp) -- see
# generate_platform_xml.py's header for why: the SimGrid available locally
# (3.25) has an incompatible S4U C++ API vs. the 4.1 the .cpp targets, and
# the XML platform DTD is the stable, version-portable equivalent. Identical
# topology, confirmed by inspection against platform_shared_nic.cpp.
PLATFORM_GEN="python3 $DIR/generate_platform_xml.py"

# Emits "v0,v1,...,v{k-1}" for the given (nodes, column), rank order 0..k-1,
# from level2_compute_constants.csv. Pure awk, no R dependency at run time.
fixed_list() { # $1 = nodes, $2 = column name (mean_boundaries_s | mean_interior_s)
  awk -F, -v nodes="$1" -v col="$2" '
    NR==1 { for (i=1;i<=NF;i++) h[$i]=i; next }
    $h["nodes"]==nodes { vals[$h["rank"]+0]=$h[col] }
    END {
      n=0; for (r in vals) if (r+1>n) n=r+1
      out=""
      for (r=0;r<n;r++) out = out (r==0?"":",") vals[r]
      print out
    }' "$CONSTANTS_CSV"
}

for nodes in "${NODES_TO_RUN[@]}"; do
  N=${ANCHOR_N[$nodes]}
  size=$(cuda_size "$N")
  total_hosts=$(( nodes * RANKS_PER_NODE ))

  boundaries_list=$(fixed_list "$nodes" "mean_boundaries_s")
  interior_list=$(fixed_list "$nodes" "mean_interior_s")
  bookkeeping_list=$(fixed_list "$nodes" "mean_bookkeeping_s")

  for bw in "${BANDWIDTHS[@]}"; do
    label="${nodes}n_${bw}"
    run_dir="$RESULTS_DIR/$label"
    mkdir -p "$run_dir"

    if grep -q "^rank,total_time,msamples_per_s" "$run_dir/dc.output" 2>/dev/null; then
      echo "=== [t=+${SECONDS}s] $label: already has a valid dc.output, skipping ==="
      continue
    fi

    echo ""
    echo "=== [t=+${SECONDS}s] $label (N=$N, size=$size, hosts=$total_hosts, bw=$bw shared/node) ==="

    export PLATFORM_NUM_NODES=$nodes
    export PLATFORM_RANKS_PER_NODE=$RANKS_PER_NODE
    export PLATFORM_NET_BW=$bw
    export PLATFORM_NET_LAT=$NET_LAT
    export PLATFORM_HOSTFILE="$run_dir/hostfile.txt"
    export PLATFORM_XML_OUT="$run_dir/platform_shared_nic.xml"

    $PLATFORM_GEN > "$run_dir/platform_gen.log" 2>&1

    ( cd "$run_dir" && rm -f dc.trace dc.csv dc.output
      DC_FIXED_BOUNDARIES_S="$boundaries_list" DC_FIXED_INTERIOR_S="$interior_list" DC_FIXED_BOOKKEEPING_S="$bookkeeping_list" \
      smpirun \
        -platform "$run_dir/platform_shared_nic.xml" \
        -hostfile "$run_dir/hostfile.txt" \
        -np "$total_hosts" \
        "${SMPI_CFG_COMMON[@]}" \
        -trace --cfg=tracing/filename:dc.trace \
        "$REPO_ROOT/bin/dc" \
        --size-x="$size" --size-y="$size" --size-z="$size" \
        --absorption=$ABSORPTION --dx=$DX --dy=$DY --dz=$DZ --dt=$DT --time-max=$TIME_MAX \
        --skip-output \
        2>&1 | tee dc.output

      if [ -f dc.trace ]; then
        pj_dump -z -l 9 dc.trace | grep ^State > dc.csv
      fi
    )

    cat > "$run_dir/metadata.txt" <<EOF
# Simulated run — Level 2 (shared-NIC chuc platform, original poti network
# calibration, real A100 compute constant substituted for online sampling)
label: $label
nodes: $nodes
ranks_per_node: $RANKS_PER_NODE
total_hosts: $total_hosts
anchor_N: $N
cuda_size: $size
bandwidth: $bw
net_lat: $NET_LAT (reused unchanged from original poti calibration)
platform: simgrid-chuc-validation/platform_shared_nic.cpp
smpi_calibration: copied verbatim from nix/scripts.nix runSimgridPlatformCuda (Cornebize methodology, poti/1Gbit/s)
compute_source: analysis/level2_compute_constants.csv (real A100, extracted from g5k/results/bench_25gbit_${nodes}n_*, ${nodes}-node topology, 5 reps, iteration>1)
boundaries_s_per_rank: $boundaries_list
interior_s_per_rank: $interior_list
bookkeeping_s_per_rank: $bookkeeping_list
iterations: $(python3 -c "print(int($TIME_MAX/$DT))")
timestamp: $(date -Iseconds)
EOF
    log_elapsed
  done
done

echo ""
echo "=== Done at t=+${SECONDS}s. Results in $RESULTS_DIR/<nodes>n_<bw>/{dc.csv,dc.output,metadata.txt} ==="
