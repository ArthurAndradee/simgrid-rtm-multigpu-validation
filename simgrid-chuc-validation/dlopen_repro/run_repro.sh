#!/usr/bin/env bash
# run_repro.sh — build and run the minimal CUDA+SMPI dlopen repro. Run this
# FIRST thing on a fresh chuc allocation, inside the project's normal Nix
# devShell (the one that has smpicc+nvcc for BACKEND=simgrid_cuda) or
# equivalent -- same toolchain bin/dc uses, so the comparison is apples to
# apples.
#
# Usage: ./run_repro.sh
#
# Interpreting the result:
#   - Same "cannot dynamically load position-independent executable" error
#     here => environmental bug (chuc driver/toolkit/SimGrid), not
#     bin/dc-specific. Stop looking at the app; look at the platform.
#   - No error, kernel runs fine => bug is specific to something in bin/dc's
#     actual build. Next: grow this repro (second .cu file, cudaMalloc-heavy
#     code, MPI halo-exchange-shaped comms) until it breaks, to isolate the
#     trigger.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

: "${CUDA_PATH:?CUDA_PATH not set -- run inside the Nix devShell with cudatoolkit}"

echo "=== Building repro (same two-step pattern as Makefile's simgrid_cuda target) ==="
nvcc -c minimal_cuda_smpi.cu -o kernel.o -Xcompiler -fPIC -ccbin g++ -DSIMGRID \
     -gencode arch=compute_80,code=sm_80 -allow-unsupported-compiler
smpicc -c host_main.c -o host_main.o -DSIMGRID
smpicc -o repro host_main.o kernel.o -L"$CUDA_PATH/lib" -L"$CUDA_PATH/lib64" \
       -lcudart -lstdc++ -lpthread -ldl -lrt

echo "=== readelf sanity check (confirm shared/no-PIE, like bin/dc was) ==="
readelf -h repro | grep Type
readelf -d repro | grep -i flags || true

echo "=== Bridging host NVIDIA driver (same pattern as run_validation.sh) ==="
DRIVER_SANDBOX=$(mktemp -d)
trap 'rm -rf "$DRIVER_SANDBOX"' EXIT
for libdir in /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib /run/opengl-driver/lib; do
  if [ -e "$libdir/libcuda.so.1" ]; then
    ln -sf "$libdir/libcuda.so.1" "$DRIVER_SANDBOX/libcuda.so.1"
    ln -sf "$libdir/libcuda.so.1" "$DRIVER_SANDBOX/libcuda.so"
    [ -e "$libdir/libnvidia-ptxjitcompiler.so.1" ] && ln -sf "$libdir/libnvidia-ptxjitcompiler.so.1" "$DRIVER_SANDBOX/libnvidia-ptxjitcompiler.so.1"
    break
  fi
done
export LD_LIBRARY_PATH="$DRIVER_SANDBOX:${LD_LIBRARY_PATH:-}"

echo "=== Minimal platform + hostfile (2 ranks, 1 host, no network needed) ==="
cat > /tmp/repro_platform.xml << 'EOF'
<?xml version='1.0'?>
<!DOCTYPE platform SYSTEM "https://simgrid.org/simgrid.dtd">
<platform version="4.1">
  <zone id="world" routing="Full">
    <host id="h0" speed="1f"/>
  </zone>
</platform>
EOF
printf 'h0\nh0\n' > /tmp/repro_hostfile.txt

echo "=== Running (privatization ON, the default that fails for bin/dc) ==="
smpirun -platform /tmp/repro_platform.xml -hostfile /tmp/repro_hostfile.txt -np 2 ./repro
echo "=== EXIT CODE: $? -- if you see this, the repro did NOT hit the dlopen bug ==="
