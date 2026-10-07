// bidir.c -- sanity check for the NIC sharing policy: ranks 0 and 1 (on
// different simulated nodes) exchange one message each way at the same
// time; then rank 0 sends one way only. Under SHARED the simultaneous
// exchange should take ~2x the one-way time; under SPLITDUPLEX ~1x.
#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  MPI_Init(&argc, &argv);
  int rank; MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  long n = argc > 1 ? atol(argv[1]) : 12L << 20;
  char *s = calloc(n, 1), *r = calloc(n, 1);
  int peer = 1 - rank; MPI_Request q[2];
  MPI_Barrier(MPI_COMM_WORLD);
  double t0 = MPI_Wtime();
  MPI_Irecv(r, n, MPI_BYTE, peer, 0, MPI_COMM_WORLD, &q[0]);
  MPI_Isend(s, n, MPI_BYTE, peer, 0, MPI_COMM_WORLD, &q[1]);
  MPI_Waitall(2, q, MPI_STATUSES_IGNORE);
  double t_bi = MPI_Wtime() - t0;
  MPI_Barrier(MPI_COMM_WORLD);
  t0 = MPI_Wtime();
  if (rank == 0) MPI_Send(s, n, MPI_BYTE, 1, 1, MPI_COMM_WORLD);
  else MPI_Recv(r, n, MPI_BYTE, 0, 1, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
  double t_uni = MPI_Wtime() - t0;
  if (rank == 1) printf("bytes=%ld bidirecional=%.4fs unidirecional=%.4fs razao=%.2f\n", n, t_bi, t_uni, t_bi / t_uni);
  MPI_Finalize();
  return 0;
}
