// minimal_cuda_smpi.cu — smallest possible CUDA+SMPI program, used to
// isolate whether the "cannot dynamically load position-independent
// executable" dlopen failure (jobs 2185769/2186228, 2026-08-12, blocking
// Level 1 / BACKEND=simgrid_cuda) is caused by something specific to
// bin/dc, or is a general CUDA+SMPI-privatization incompatibility on chuc.
//
// If THIS also fails with the same dlopen error: the bug is environmental
// (chuc's CUDA driver/toolkit/SMPI combination), not anything about the
// distributed-cube-average codebase -- stop looking at bin/dc's source and
// look at the platform (driver version, nvcc version, SimGrid build flags).
//
// If THIS succeeds: the bug is specific to something in bin/dc's build
// (its actual CUDA kernels, its many translation units, cudart usage
// pattern, etc.) -- next step is to grow this repro incrementally (add a
// second .cu file, add cudaMalloc, add a real kernel launch, add MPI
// halo-exchange-shaped communication) until it reproduces the failure, to
// find exactly which ingredient triggers it.
//
// Build (inside the Nix devShell that has smpicc + nvcc for BACKEND=
// simgrid_cuda, i.e. the SAME toolchain bin/dc normally uses on chuc):
//   smpicc -c minimal_cuda_smpi.cu -o /dev/null 2>/dev/null || true  # (not a .c file, see below)
// Actually build with the same two-step pattern as the Makefile's
// simgrid_cuda target:
//   nvcc -c minimal_cuda_smpi.cu -o kernel.o -Xcompiler -fPIC -ccbin g++ -DSIMGRID \
//        -gencode arch=compute_80,code=sm_80 -allow-unsupported-compiler
//   smpicc -c host_main.c -o host_main.o -DSIMGRID
//   smpicc -o repro host_main.o kernel.o -L$CUDA_PATH/lib64 -lcudart -lstdc++ -lpthread -ldl -lrt
// Run:
//   smpirun -platform <any-platform>.xml -hostfile <hostfile> -np 2 ./repro
#include <cuda_runtime.h>
#include <cstdio>

__global__ void trivial_kernel(float *data) {
  data[0] = 42.0f;
}

extern "C" void run_trivial_kernel() {
  float *d;
  cudaMalloc(&d, sizeof(float));
  trivial_kernel<<<1, 1>>>(d);
  cudaDeviceSynchronize();
  cudaFree(d);
}
