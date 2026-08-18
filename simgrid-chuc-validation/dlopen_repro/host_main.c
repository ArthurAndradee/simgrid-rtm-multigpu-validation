// host_main.c — MPI/SMPI driver for minimal_cuda_smpi.cu. See that file's
// header for why this exists (isolating the dlopen bug blocking Level 1).
#include <mpi.h>
#include <stdio.h>

extern void run_trivial_kernel();

int main(int argc, char **argv) {
  MPI_Init(&argc, &argv);
  int rank;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  printf("rank %d: calling CUDA kernel\n", rank);
  run_trivial_kernel();
  printf("rank %d: kernel done\n", rank);
  MPI_Barrier(MPI_COMM_WORLD);
  MPI_Finalize();
  return 0;
}
