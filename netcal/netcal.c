// netcal.c -- raw data collection for re-running Cornebize's SMPI network
// calibration on chuc. The smpi/os, or, ois, bw-factor, lat-factor, iprobe
// and test values in use come from PCAD's poti cluster (RTX4070, 1 Gbit/s),
// with breakpoints up to 65480 bytes; samples here go up to 16 MiB.
//
// This program only COLLECTS samples; the piecewise-linear fitting
// (breakpoints, os/or/ois coefficients, bw/lat factors) is done offline.
//
// Two ranks, one per physical node. For a fixed wall-clock budget it draws
// (operation, size) pairs at random -- sizes log-uniform in [1, MAX_SIZE],
// order randomized so drift/background noise spreads over all sizes instead
// of biasing one range -- and records one duration per sample:
//
//   pingpong  rank 0: Send+Recv round trip, recorded as the full RTT
//   send      rank 0: blocking MPI_Send duration (receiver already posted)
//   isend     rank 0: MPI_Isend call duration only (MPI_Wait not timed)
//   recv      rank 1: MPI_Recv duration for a message that has already
//             arrived (sender sends, receiver waits it out before timing)
//   iprobe    rank 1: one MPI_Iprobe call (no message pending)
//   test      rank 0: one MPI_Test call on a pending Irecv
//
// Output (stdout, rank 0 only): op,size,duration_s
//
// Usage: mpirun -np 2 (one rank per node) ./netcal [budget_s] [max_size] [seed]
#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <unistd.h>

enum { OP_PINGPONG, OP_SEND, OP_ISEND, OP_RECV, OP_IPROBE, OP_TEST, N_OPS };
static const char *op_name[N_OPS] = {"pingpong", "send", "isend", "recv",
                                     "iprobe", "test"};

#define TAG_DATA 1
#define TAG_CTRL 2
#define TAG_TEST 3
#define TAG_RESULT 4

static long draw_size(long max_size) {
  double u = (double)rand() / RAND_MAX;
  long s = (long)floor(exp(u * log((double)max_size)));
  return s < 1 ? 1 : s;
}

int main(int argc, char **argv) {
  MPI_Init(&argc, &argv);
  int rank, size;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Comm_size(MPI_COMM_WORLD, &size);
  if (size != 2) {
    if (rank == 0) fprintf(stderr, "netcal: needs exactly 2 ranks\n");
    MPI_Abort(MPI_COMM_WORLD, 1);
  }

  double budget = argc > 1 ? atof(argv[1]) : 120.0;
  long max_size = argc > 2 ? atol(argv[2]) : 16L * 1024 * 1024;
  unsigned seed = argc > 3 ? (unsigned)atoi(argv[3]) : 42;
  srand(seed);

  char *buf = malloc(max_size);
  memset(buf, 0x5A, max_size);
  int peer = 1 - rank;

  if (rank == 0) printf("op,size,duration_s\n");

  MPI_Barrier(MPI_COMM_WORLD);
  double t_begin = MPI_Wtime();

  for (;;) {
    // rank 0 decides the next (op, size) and the stop condition; rank 1 obeys.
    long cmd[2];
    if (rank == 0) {
      int stop = (MPI_Wtime() - t_begin) > budget;
      cmd[0] = stop ? -1 : rand() % N_OPS;
      cmd[1] = draw_size(max_size);
    }
    MPI_Bcast(cmd, 2, MPI_LONG, 0, MPI_COMM_WORLD);
    if (cmd[0] < 0) break;
    int op = (int)cmd[0];
    long n = cmd[1];
    double t0, dt = -1;

    MPI_Barrier(MPI_COMM_WORLD);
    switch (op) {
    case OP_PINGPONG:
      if (rank == 0) {
        t0 = MPI_Wtime();
        MPI_Send(buf, n, MPI_BYTE, peer, TAG_DATA, MPI_COMM_WORLD);
        MPI_Recv(buf, n, MPI_BYTE, peer, TAG_DATA, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
        dt = MPI_Wtime() - t0;
      } else {
        MPI_Recv(buf, n, MPI_BYTE, peer, TAG_DATA, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
        MPI_Send(buf, n, MPI_BYTE, peer, TAG_DATA, MPI_COMM_WORLD);
      }
      break;
    case OP_SEND:
      if (rank == 0) {
        t0 = MPI_Wtime();
        MPI_Send(buf, n, MPI_BYTE, peer, TAG_DATA, MPI_COMM_WORLD);
        dt = MPI_Wtime() - t0;
      } else {
        MPI_Recv(buf, n, MPI_BYTE, peer, TAG_DATA, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
      }
      break;
    case OP_ISEND:
      if (rank == 0) {
        MPI_Request r;
        t0 = MPI_Wtime();
        MPI_Isend(buf, n, MPI_BYTE, peer, TAG_DATA, MPI_COMM_WORLD, &r);
        dt = MPI_Wtime() - t0;
        MPI_Wait(&r, MPI_STATUS_IGNORE);
      } else {
        MPI_Recv(buf, n, MPI_BYTE, peer, TAG_DATA, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
      }
      break;
    case OP_RECV:
      if (rank == 0) {
        MPI_Request r;
        MPI_Isend(buf, n, MPI_BYTE, peer, TAG_DATA, MPI_COMM_WORLD, &r);
        MPI_Wait(&r, MPI_STATUS_IGNORE);
      } else {
        // Wait until the message is fully available locally before timing
        // the Recv itself (for rendezvous-sized messages MPI_Recv still
        // triggers the transfer -- that is what smpi/or has to capture).
        int flag = 0;
        while (!flag)
          MPI_Iprobe(peer, TAG_DATA, MPI_COMM_WORLD, &flag, MPI_STATUS_IGNORE);
        t0 = MPI_Wtime();
        MPI_Recv(buf, n, MPI_BYTE, peer, TAG_DATA, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
        dt = MPI_Wtime() - t0;
      }
      break;
    case OP_IPROBE:
      if (rank == 1) {
        int flag;
        t0 = MPI_Wtime();
        MPI_Iprobe(peer, TAG_CTRL, MPI_COMM_WORLD, &flag, MPI_STATUS_IGNORE);
        dt = MPI_Wtime() - t0;
      }
      n = 0;
      break;
    case OP_TEST:
      // TAG_TEST is only ever sent by rank 1 after rank 0 signals it is done
      // timing, so the Irecv is guaranteed still pending during MPI_Test.
      if (rank == 0) {
        MPI_Request r;
        int flag;
        MPI_Irecv(buf, 1, MPI_BYTE, peer, TAG_TEST, MPI_COMM_WORLD, &r);
        t0 = MPI_Wtime();
        MPI_Test(&r, &flag, MPI_STATUS_IGNORE);
        dt = MPI_Wtime() - t0;
        MPI_Send(buf, 1, MPI_BYTE, peer, TAG_CTRL, MPI_COMM_WORLD);
        MPI_Wait(&r, MPI_STATUS_IGNORE);
      } else {
        MPI_Recv(buf, 1, MPI_BYTE, peer, TAG_CTRL, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
        MPI_Send(buf, 1, MPI_BYTE, peer, TAG_TEST, MPI_COMM_WORLD);
      }
      n = 0;
      break;
    }

    // ship rank 1's measurement to rank 0 so a single stream holds it all
    double rec = dt;
    if (op == OP_RECV || op == OP_IPROBE) {
      if (rank == 1) MPI_Send(&dt, 1, MPI_DOUBLE, 0, TAG_RESULT, MPI_COMM_WORLD);
      else MPI_Recv(&rec, 1, MPI_DOUBLE, 1, TAG_RESULT, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
    }
    if (rank == 0) printf("%s,%ld,%.9f\n", op_name[op], n, rec);
  }

  free(buf);
  MPI_Finalize();
  return 0;
}
