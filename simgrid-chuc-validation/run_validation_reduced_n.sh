#!/usr/bin/env bash
# run_validation_reduced_n.sh — Level 1, 3-node and 4-node ONLY, at a
# REDUCED anchor N=1800 (cuda_size=1788) instead of the original weak-
# scaling table's N=1920/2176.
#
# WHY: the original N (1920/2176) OOMs real GPU VRAM on a single real chuc
# node's 4x A100-40GB when SMPI oversubscribes 3-4 simulated ranks per real
# GPU (SMPI always runs one whole simulated job inside ONE real OS process
# on ONE real machine, regardless of how many chuc nodes are allocated --
# see simgrid-chuc-validation/LEVEL2_FINDINGS.md section 6.4). N=1800 was
# chosen (see /tmp/calc_reduced_n.py in the conversation, or re-derive: 6
# device float arrays/rank, empirically-confirmed MPI_Dims_create
# topologies (3,2,2) for 3-node and (4,2,2) for 4-node, worst-case local
# partition size including remainder) to keep every real A100 GPU under
# ~36GB (85-89% of 40GiB), leaving headroom for CUDA context/driver/MPI
# buffer overhead beyond the 6 tracked arrays:
#   3-node: 3 ranks/GPU x 11.89GB/rank = 35.66GB/GPU
#   4-node: 4 ranks/GPU x  8.94GB/rank = 35.77GB/GPU
#
# IMPORTANT: this N is DELIBERATELY DIFFERENT from the real campaign's
# Table 3 anchor sizes for 3-4 nodes -- it is NOT directly comparable to
# Table 3's published real 3-4 node numbers. It IS comparable to a NEW real
# reference run at the SAME N=1800, launched via the real campaign's own
# g5k/01-05 scripts (unmodified) on a real, undivided (1 rank/GPU) chuc
# allocation -- see simgrid-chuc-validation/REDUCED_N_RUNBOOK.md for that
# real-run half of this comparison.
#
# Same machinery as run_validation.sh otherwise (SMPI_CFG_COMMON, driver
# bridge, shared-NIC platform, contexts/factory:thread fix) -- copied, not
# sourced, to keep run_validation.sh's original weak-scaling table
# untouched and independently re-runnable.
#
# Needs exactly ONE real chuc node with real A100s (same as
# run_validation.sh -- see its header for why more nodes don't help a
# single smpirun invocation).
#
# Usage: ./run_validation_reduced_n.sh [node-count list, default 3,4]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DIR/.." && pwd)"
cd "$REPO_ROOT"

RESULTS_DIR="$DIR/results_reduced_n"
mkdir -p "$RESULTS_DIR"

NODE_LIST="${1:-3,4}"
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

# Single reduced anchor N for BOTH 3-node and 4-node (both converge to
# almost the same safe max under the VRAM budget -- see header derivation).
declare -A ANCHOR_N=( [3]=1800 [4]=1800 )
RANKS_PER_NODE=4
BANDWIDTHS=(1Gbps 10Gbps 25Gbps)
NET_LAT="22.7us"

SMPI_CFG_COMMON=(
  --cfg=contexts/factory:thread
  --cfg=smpi/display-timing:yes
  --cfg=precision/timing:1e-9
  --cfg=tracing/precision:9
  --cfg=smpi/shared-malloc:global
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

DRIVER_SANDBOX=$(mktemp -d)
trap 'rm -rf "$DRIVER_SANDBOX"' EXIT
for libdir in /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib /run/opengl-driver/lib; do
  if [ -e "$libdir/libcuda.so.1" ]; then
    echo "Found host CUDA driver in: $libdir"
    ln -sf "$libdir/libcuda.so.1" "$DRIVER_SANDBOX/libcuda.so.1"
    ln -sf "$libdir/libcuda.so.1" "$DRIVER_SANDBOX/libcuda.so"
    [ -e "$libdir/libnvidia-ptxjitcompiler.so.1" ] && ln -sf "$libdir/libnvidia-ptxjitcompiler.so.1" "$DRIVER_SANDBOX/libnvidia-ptxjitcompiler.so.1"
    break
  fi
done
if [ -e "$DRIVER_SANDBOX/libcuda.so.1" ]; then
  export LD_LIBRARY_PATH="$DRIVER_SANDBOX:${LD_LIBRARY_PATH:-}"
else
  echo "WARNING: could not find host libcuda.so.1 in any standard path -- CUDA calls will likely fail."
fi

echo "=== [t=+${SECONDS}s] Building dc (BACKEND=simgrid_cuda, BUILDDIR=bin_sim) ==="
# BUILDDIR=bin_sim (Makefile's BUILDDIR is a plain, command-line-overridable
# var -- confirmed 2026-08-13): keeps this build's bin_sim/dc + bin_sim/obj/
# completely separate from the real campaign's BACKEND=cuda build, which
# writes to the default bin/dc. Needed because this script may run
# CONCURRENTLY with a real g5k benchmark run on the same shared NFS repo
# checkout (2026-08-14 reduced-N session, 4 chuc nodes, tight walltime) --
# without this, whichever build finishes last silently clobbers the other's
# binary mid-run.
make all BACKEND=simgrid_cuda BUILDDIR=bin_sim
log_elapsed

echo "=== [t=+${SECONDS}s] Compiling shared-NIC platform ==="
bash "$DIR/compile_platform.sh"
log_elapsed

for nodes in "${NODES_TO_RUN[@]}"; do
  N=${ANCHOR_N[$nodes]}
  size=$(cuda_size "$N")
  total_hosts=$(( nodes * RANKS_PER_NODE ))

  for bw in "${BANDWIDTHS[@]}"; do
    label="${nodes}n_${bw}"
    run_dir="$RESULTS_DIR/$label"
    mkdir -p "$run_dir"

    if grep -q "^rank,total_time,msamples_per_s" "$run_dir/dc.output" 2>/dev/null; then
      echo "=== [t=+${SECONDS}s] $label: already has a valid dc.output, skipping ==="
      continue
    fi

    echo ""
    echo "=== [t=+${SECONDS}s] $label (N=$N [REDUCED], size=$size, hosts=$total_hosts, bw=$bw shared/node, lat=$NET_LAT) ==="

    export PLATFORM_NUM_NODES=$nodes
    export PLATFORM_RANKS_PER_NODE=$RANKS_PER_NODE
    export PLATFORM_NET_BW=$bw
    export PLATFORM_NET_LAT=$NET_LAT
    export PLATFORM_HOSTFILE="$run_dir/hostfile.txt"

    # BUG FIX (2026-08-14 review): this call was previously OUTSIDE the
    # protective subshell below, so a failure here (before smpirun even
    # runs) would still trip the top-level `set -e` and kill the entire
    # script/remaining configs -- same class of bug as the smpirun one,
    # just one step earlier. `continue` to the next (nodes,bw) instead of
    # letting `set -e` abort everything.
    if ! "$DIR/generate_artifacts_shared_nic" > "$run_dir/platform_gen.log" 2>&1; then
      echo "!!! WARNING: $label platform generation FAILED (see $run_dir/platform_gen.log) -- skipping this config, continuing to the next."
      continue
    fi

    # BUG FIX (2026-08-14 review): this whole script runs under `set -e`
    # (inherited from run_validation.sh, appropriate for the build/setup
    # steps above). Left unguarded, a single crashed/nonzero smpirun here
    # would abort the ENTIRE script immediately -- silently skipping every
    # remaining config in the loop. This is not hypothetical: the exact
    # same `set -euo pipefail` behavior killed run_validation.sh outright
    # on chuc-7 earlier the same day this file was written (see
    # LEVEL2_FINDINGS.md sec 6.4) after ONE fatal smpirun failure. Wrapped
    # in `|| true` + explicit status check so one bad config is logged and
    # the loop continues to the next one, matching run_reduced_n_real.sh's
    # per-config resilience (`run_one` there never aborts the whole script
    # either).
    (
      set -e
      cd "$run_dir" && rm -f dc.trace dc.csv dc.output
      smpirun \
        -platform "$DIR/libplatform_shared_nic.so" \
        -hostfile "$run_dir/hostfile.txt" \
        -np "$total_hosts" \
        "${SMPI_CFG_COMMON[@]}" \
        -trace --cfg=tracing/filename:dc.trace \
        "$REPO_ROOT/bin_sim/dc" \
        --size-x="$size" --size-y="$size" --size-z="$size" \
        --absorption=$ABSORPTION --dx=$DX --dy=$DY --dz=$DZ --dt=$DT --time-max=$TIME_MAX \
        --skip-output \
        2>&1 | tee dc.output

      if [ -f dc.trace ]; then
        pj_dump -z -l 9 dc.trace | grep ^State > dc.csv
      fi
    ) || echo "!!! WARNING: $label FAILED (see $run_dir/dc.output) -- continuing to the next config, NOT aborting the whole session."

    cat > "$run_dir/metadata.txt" <<EOF
# Simulated run — REDUCED N=$N (NOT Table 3's original anchor) to fit real
# A100 VRAM under SMPI's single-real-machine oversubscription. Compare
# against a REAL reference run at the SAME N (see REDUCED_N_RUNBOOK.md),
# NOT against Table 3's published 3-4 node numbers (different N).
label: $label
nodes: $nodes
ranks_per_node: $RANKS_PER_NODE
total_hosts: $total_hosts
anchor_N: $N (REDUCED from original Table 3 anchor -- see script header)
cuda_size: $size
bandwidth: $bw
net_lat: $NET_LAT (reused unchanged from original poti calibration)
platform: simgrid-chuc-validation/platform_shared_nic.cpp
smpi_calibration: copied verbatim from run_validation.sh
iterations: $(python3 -c "print(int($TIME_MAX/$DT))")
timestamp: $(date -Iseconds)
EOF
    log_elapsed
  done
done

echo ""
echo "=== Done at t=+${SECONDS}s. Results in $RESULTS_DIR/<nodes>n_<bw>/{dc.csv,dc.output,metadata.txt} ==="
echo "Compare against the REAL reference run at the same N=1800 (see"
echo "simgrid-chuc-validation/REDUCED_N_RUNBOOK.md), NOT against Table 3."
