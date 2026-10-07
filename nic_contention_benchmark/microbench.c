// microbench.c -- tests Hypothesis 2 of LEVEL2_FINDINGS.md sec 6.7: does the
// real 1Gbit/s-shaped NIC serve 4 concurrent same-node senders with genuine
// simultaneous, continuous max-min fair-share (each pinned at ~1/4 line rate
// for the WHOLE transfer, as platform_shared_nic.cpp's SimGrid model
// assumes), or does real hardware/OS scheduling stagger completions (each
// send getting closer to full line rate for a growing fraction of its own
// duration as siblings finish)?
//
// Design: RANKS_PER_NODE senders on node A (ranks 0..RANKS_PER_NODE-1), the
// same number of matching receivers on node B (ranks RANKS_PER_NODE..
// 2*RANKS_PER_NODE-1), one sender per receiver. MPI_Barrier releases all
// senders together each trial; each sender times its own MPI_Isend+MPI_Wait
// with MPI_Wtime(), relative to the barrier release. MSG_BYTES defaults to
// 13,631,488 -- the real N=1800 halo face size measured in the reduced-N
// session (LEVEL2_FINDINGS.md sec 6.7, hypothesis-1 probe).
//
// Idealized (SimGrid platform_shared_nic.cpp) prediction under perfect
// continuous fair-share: every sender finishes at ~the same time,
// end_offset_s ~= MSG_BYTES*8 / (net_bw_bps/RANKS_PER_NODE) for all ranks.
// Real-hardware staggering (Hypothesis 2) predicts a SPREAD across ranks'
// end_offset_s -- some finishing well before that idealized time, at
// least one near or after it (since total bytes moved is conserved, NOT
// every rank can finish early).
//
// Output: one CSV line per (rank, trial) to stdout, on the sender side only
// (rank < RANKS_PER_NODE): rank,trial,start_offset_s,end_offset_s,duration_s
//
// Usage: mpirun -np 2*RANKS_PER_NODE --hostfile <2 nodes, RANKS_PER_NODE
//   slots each> ./microbench [msg_bytes] [n_trials]
#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define RANKS_PER_NODE 4

int main(int argc, char **argv) {
  MPI_Init(&argc, &argv);
  int rank, size;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Comm_size(MPI_COMM_WORLD, &size);

  if (size != 2 * RANKS_PER_NODE) {
    if (rank == 0)
      fprintf(stderr,
              "microbench: expected exactly %d ranks (%d senders + %d "
              "receivers), got %d\n",
              2 * RANKS_PER_NODE, RANKS_PER_NODE, RANKS_PER_NODE, size);
    MPI_Abort(MPI_COMM_WORLD, 1);
  }

  long msg_bytes = (argc > 1) ? atol(argv[1]) : 13631488L;
  int n_trials = (argc > 2) ? atoi(argv[2]) : 20;
  int is_sender = rank < RANKS_PER_NODE;
  int peer = is_sender ? rank + RANKS_PER_NODE : rank - RANKS_PER_NODE;

  char *buf = malloc(msg_bytes);
  if (buf == NULL) {
    fprintf(stderr, "[%d] OOM allocating %ld bytes\n", rank, msg_bytes);
    MPI_Abort(MPI_COMM_WORLD, 1);
  }
  memset(buf, 0x5A, msg_bytes);

  if (rank == 0)
    printf("rank,trial,start_offset_s,end_offset_s,duration_s\n");

  for (int trial = 0; trial < n_trials; trial++) {
    MPI_Request req;
    MPI_Barrier(MPI_COMM_WORLD);
    double t_barrier = MPI_Wtime();

    if (is_sender) {
      MPI_Isend(buf, msg_bytes, MPI_BYTE, peer, trial, MPI_COMM_WORLD, &req);
      MPI_Wait(&req, MPI_STATUS_IGNORE);
      double t_end = MPI_Wtime();
      printf("%d,%d,%.6f,%.6f,%.6f\n", rank, trial, 0.0, t_end - t_barrier,
             t_end - t_barrier);
      fflush(stdout);
    } else {
      MPI_Irecv(buf, msg_bytes, MPI_BYTE, peer, trial, MPI_COMM_WORLD, &req);
      MPI_Wait(&req, MPI_STATUS_IGNORE);
    }
    // let stdout drain and peers settle before the next trial's barrier,
    // so one trial's tail traffic cannot bleed into the next trial's timing
    MPI_Barrier(MPI_COMM_WORLD);
  }

  free(buf);
  MPI_Finalize();
  return 0;
}
