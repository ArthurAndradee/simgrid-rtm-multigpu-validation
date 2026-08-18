#!/usr/bin/env bash
# run_validation.sh — Option C validation: original Spadotto/poti Cornebize
# network calibration, replayed against the NEW shared-NIC chuc platform
# (platform_shared_nic.cpp), CUDA backend, native GPU kernel sampling (SMPI
# online simulation), at the same 4 node-counts x 3 bandwidths x anchor-N
# used by the real campaign (Table 3 / analysis/results_package).
#
# Needs exactly ONE chuc node (or any single machine with >=1 real GPU): all
# 1-4 "simulated nodes" run as SMPI ranks inside ONE physical process on
# that one machine -- SimGrid does not need N physical machines to simulate
# an N-node MPI job. See project conversation log for why.
#
# Run from inside `nix-shell simgrid-chuc-validation/shell.nix` at the repo
# root -- a MINIMAL shell (simgrid, cudatoolkit, openmpi, pajeng only), not
# the full flake devShell, to cut warm-up time under a tight walltime.
# `make` target BACKEND=simgrid_cuda builds the app. Does NOT touch g5k/,
# the real campaign's checkpoint, or simgrid-config/ -- everything read or
# written lives under simgrid-chuc-validation/.
#
# Resumable: a run whose dc.output already has a valid throughput line is
# skipped (not re-executed), so an interrupted session (walltime ran out)
# can continue later, on the same or a different chuc node, without losing
# completed configurations.
#
# Order runs 1-node -> 4-node (cheapest/most-informative first): pass a
# comma-separated node-count list in $1 to run only a subset, e.g.
#   ./run_validation.sh 1,2      # on chuc node A
#   ./run_validation.sh 3,4      # on chuc node B, in parallel
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DIR/.." && pwd)"
cd "$REPO_ROOT"

RESULTS_DIR="$DIR/results"
mkdir -p "$RESULTS_DIR"

NODE_LIST="${1:-1,2,3,4}"
IFS=',' read -r -a NODES_TO_RUN <<< "$NODE_LIST"

SECONDS=0 # bash builtin, reset here; used for elapsed-time logging below
log_elapsed() { echo "    [t=+${SECONDS}s elapsed since script start]"; }

# --- Fletcher domain math: identical constants to g5k/conf/defaults.conf,
# copied (not sourced) so this directory has no dependency on g5k/. ---------
STENCIL=4
ABSORPTION=2
DX=1e-1
DY=1e-1
DZ=1e-1
DT=1e-6
TIME_MAX=1e-4   # TIME_MAX/DT = 100 iterations, same as the real campaign
                # (the ORIGINAL nix/scripts.nix runSimGridExperiments used
                # 1e-3 = 1000 iterations for a different, older comparison --
                # NOT reused here, since it would no longer match Table 3's
                # real measurements, which are all 100-iteration runs).

cuda_size() { # $1 = Tamanho_Global_N (anchor)
  echo $(( $1 - 2*STENCIL - 2*ABSORPTION ))
}

# --- The 4 anchor N used in Table 3 (main.tex) / RESULTADOS_PACOTE.md,
# identical to g5k/csv/experimentos.csv's weak-scaling design. ---------------
declare -A ANCHOR_N=( [1]=1344 [2]=1728 [3]=1920 [4]=2176 )
RANKS_PER_NODE=4
BANDWIDTHS=(1Gbps 10Gbps 25Gbps)

# --- Network latency: reused UNCHANGED from the original poti calibration
# (nix/scripts.nix run-poti-experiments: NET_LAT="22.7us"). No chuc-specific
# latency calibration exists, so this is an explicit, documented assumption,
# not a silent guess -- flag it in the write-up. ----------------------------
NET_LAT="22.7us"

# --- Cornebize-calibrated SMPI protocol parameters, copied VERBATIM from
# nix/scripts.nix's runSimgridPlatformCuda (same values used for every
# figure/number already published from the original poti calibration).
# Nothing here is recalibrated -- only the -platform lib and -hostfile
# (and therefore the network TOPOLOGY) differ from the original script. ----
SMPI_CFG_COMMON=(
  # UPDATE 2026-08-13 (fresh chuc-7/chuc-8 allocation, CUDA 12.8 / SimGrid
  # 4.0 via the flake devShell): the dlopen bug documented below did NOT
  # reproduce at all in this environment -- both the minimal repro
  # (dlopen_repro/) and the real bin/dc got past SMPI privatization/loading
  # cleanly with the default --cfg=smpi/privatization:ON. Root cause of the
  # original bug still unconfirmed (plausibly a CUDA/SimGrid/driver version
  # combination specific to the old build), but since it's absent here, the
  # privatization:no workaround below is DROPPED -- it was never a real fix
  # (see the original comment, kept for history in git blame) and disabling
  # privatization risks its own correctness issues (global/static state
  # shared across ranks in one process) that were never exercised while
  # this workaround was masking the unrelated dlopen crash.
  #
  # NEW real bug found + fixed instead, once dlopen was out of the way:
  # "CUDA kernel error in dc_propagate: an illegal memory access" /
  # "unspecified launch failure", consistently reproducible at both a small
  # (256^3) and the real np=4 anchor (N=1344) size, root-caused via
  # compute-sanitizer to add_source_kernel dereferencing a device pointer
  # that belonged to the WRONG CUDA device context. Cause: SMPI's default
  # actor scheduler (--cfg=contexts/factory, default "ucontext") runs all
  # simulated ranks as cooperative coroutines on a SINGLE real OS thread --
  # but cudaSetDevice()'s "current device" is OS-thread-local state, not
  # per-rank state, so when SMPI cooperatively switches from one rank's
  # coroutine to another's mid-run, the CUDA "current device" silently
  # changes underneath the first rank, and its next kernel launch/pointer
  # dereference lands in the wrong device's address space. Fixed by forcing
  # SMPI to give each rank a REAL OS thread (contexts/factory:thread)
  # instead, which makes CUDA's per-thread device state correctly track
  # per-rank state again. Confirmed fixed at both 256^3/np=4 and the real
  # N=1344/np=4 anchor size (both completed cleanly, valid throughput
  # printed, no crash) -- see simgrid-chuc-validation/LEVEL2_FINDINGS.md
  # (Level 1 section) for the full debugging narrative.
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

# --- Bridge the host's real NVIDIA driver into the Nix CUDA toolkit's view:
# Nix's cudatoolkit ships nvcc/runtime libs but not the proprietary driver
# (libcuda.so.1), which only exists on the actual deployed host. Same
# search-standard-paths approach nix/scripts.nix's runSimgridPlatformCuda
# already uses (copied, not modified) -- this script doesn't depend on
# g5k/lib/setup.sh's separate /tmp/nv-bridge step, which this directory
# deliberately doesn't call (see deploy.sh header). ------------------------
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

echo "=== [t=+${SECONDS}s] Building dc (BACKEND=simgrid_cuda) ==="
make all BACKEND=simgrid_cuda
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
    echo "=== [t=+${SECONDS}s] $label (N=$N, size=$size, hosts=$total_hosts, bw=$bw shared/node, lat=$NET_LAT) ==="

    export PLATFORM_NUM_NODES=$nodes
    export PLATFORM_RANKS_PER_NODE=$RANKS_PER_NODE
    export PLATFORM_NET_BW=$bw
    export PLATFORM_NET_LAT=$NET_LAT
    export PLATFORM_HOSTFILE="$run_dir/hostfile.txt"

    "$DIR/generate_artifacts_shared_nic" > "$run_dir/platform_gen.log" 2>&1

    ( cd "$run_dir" && rm -f dc.trace dc.csv dc.output
      smpirun \
        -platform "$DIR/libplatform_shared_nic.so" \
        -hostfile "$run_dir/hostfile.txt" \
        -np "$total_hosts" \
        "${SMPI_CFG_COMMON[@]}" \
        -trace --cfg=tracing/filename:dc.trace \
        "$REPO_ROOT/bin/dc" \
        --size-x="$size" --size-y="$size" --size-z="$size" \
        --absorption=$ABSORPTION --dx=$DX --dy=$DY --dz=$DZ --dt=$DT --time-max=$TIME_MAX \
        --skip-output \
        2>&1 | tee dc.output

      # Same trace->CSV conversion as the real campaign (g5k/lib/*.sh), so
      # the existing analysis/masking_effectiveness.R and
      # results/scripts/common.R::read_trace_csv() read this unmodified.
      if [ -f dc.trace ]; then
        pj_dump -z -l 9 dc.trace | grep ^State > dc.csv
      fi
    )

    cat > "$run_dir/metadata.txt" <<EOF
# Simulated run — Option C (shared-NIC chuc platform, original poti network calibration)
label: $label
nodes: $nodes
ranks_per_node: $RANKS_PER_NODE
total_hosts: $total_hosts
anchor_N: $N
cuda_size: $size
bandwidth: $bw
net_lat: $NET_LAT (reused unchanged from original poti calibration -- not chuc-specific)
platform: simgrid-chuc-validation/platform_shared_nic.cpp
smpi_calibration: copied verbatim from nix/scripts.nix runSimgridPlatformCuda (Cornebize methodology, poti/1Gbit/s)
iterations: $(python3 -c "print(int($TIME_MAX/$DT))")
timestamp: $(date -Iseconds)
EOF
    log_elapsed
  done
done

echo ""
echo "=== Done at t=+${SECONDS}s. Results in $RESULTS_DIR/<nodes>n_<bw>/{dc.csv,dc.output,metadata.txt} ==="
echo "Next (run via 'conda activate r-analysis', NOT the nix shell -- see README.md):"
echo "  Rscript simgrid-chuc-validation/compute_fidelity_error.R"
