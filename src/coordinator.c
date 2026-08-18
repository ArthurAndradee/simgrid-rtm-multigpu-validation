#include <math.h>
#include <mpi.h>
#include <stdio.h>
#include <string.h>

#include "coordinator.h"
#include "indexing.h"
#include "log.h"
#include "stdlib.h"

void dc_determine_source(size_t size_x, size_t size_y, size_t size_z,
                         size_t *source_x, size_t *source_y, size_t *source_z) {
  *source_x = size_x / 2;
  *source_y = size_y / 2;
  *source_z = size_z / 2;
}

// Lightweight distribution: only sends partition info, workers compute locally
void dc_distribute_partition_info(MPI_Comm comm, unsigned int *topology,
                                  dc_arguments_t arguments,
                                  size_t num_workers) {
  size_t global_sx =
      arguments.size_x + 2 * arguments.absorption_size + 2 * STENCIL;
  size_t global_sy =
      arguments.size_y + 2 * arguments.absorption_size + 2 * STENCIL;
  size_t global_sz =
      arguments.size_z + 2 * arguments.absorption_size + 2 * STENCIL;

  size_t partition_size_x = (global_sx - 2 * STENCIL) / topology[0];
  size_t partition_size_y = (global_sy - 2 * STENCIL) / topology[1];
  size_t partition_size_z = (global_sz - 2 * STENCIL) / topology[2];
  size_t remainder_x = (global_sx - 2 * STENCIL) % topology[0];
  size_t remainder_y = (global_sy - 2 * STENCIL) % topology[1];
  size_t remainder_z = (global_sz - 2 * STENCIL) % topology[2];

  unsigned int iterations = ceil(arguments.time_max / arguments.dt);

  size_t source_x, source_y, source_z;
  dc_determine_source(global_sx, global_sy, global_sz, &source_x, &source_y,
                      &source_z);

  dc_log_info(COORDINATOR, "Distributing partition info to %zu workers...",
              num_workers);
  dc_log_info(COORDINATOR, "Global sizes: %zu x %zu x %zu", global_sx,
              global_sy, global_sz);
  dc_log_info(COORDINATOR, "Partition sizes: %zu x %zu x %zu", partition_size_x,
              partition_size_y, partition_size_z);

  for (size_t worker_z = 0; worker_z < topology[2]; worker_z++) {
    for (size_t worker_y = 0; worker_y < topology[1]; worker_y++) {
      for (size_t worker_x = 0; worker_x < topology[0]; worker_x++) {
        int process_coordinates[DIMENSIONS] = {(int)worker_x, (int)worker_y,
                                               (int)worker_z};
        int worker;
        MPI_Cart_rank(comm, process_coordinates, &worker);

        if (worker == COORDINATOR)
          continue;

        size_t local_size_x = (worker_x == topology[0] - 1)
                                  ? partition_size_x + remainder_x
                                  : partition_size_x;
        size_t local_size_y = (worker_y == topology[1] - 1)
                                  ? partition_size_y + remainder_y
                                  : partition_size_y;
        size_t local_size_z = (worker_z == topology[2] - 1)
                                  ? partition_size_z + remainder_z
                                  : partition_size_z;
        local_size_x += 2 * STENCIL;
        local_size_y += 2 * STENCIL;
        local_size_z += 2 * STENCIL;

        size_t start_x = worker_x * partition_size_x;
        size_t start_y = worker_y * partition_size_y;
        size_t start_z = worker_z * partition_size_z;

        // long (not int): same truncation bug as src/main.c's coordinator
        // source_index (see comment there) -- here local_size_x/y/z is a
        // per-WORKER partition, which for the campaign's weak-scaling CSV
        // stays well under INT32_MAX, but there is no such guarantee in
        // general (e.g. very few workers with a very large N), so fixed
        // for consistency with the sibling sites rather than left as a
        // narrower, harder-to-audit exception.
        long source_index = -1;
        if (source_x >= start_x && source_x < start_x + local_size_x &&
            source_y >= start_y && source_y < start_y + local_size_y &&
            source_z >= start_z && source_z < start_z + local_size_z) {
          size_t local_source_x = source_x - start_x;
          size_t local_source_y = source_y - start_y;
          size_t local_source_z = source_z - start_z;
          source_index = (long)dc_get_index_for_coordinates(
              local_source_x, local_source_y, local_source_z, local_size_x,
              local_size_y, local_size_z);
          dc_log_info(COORDINATOR,
                      "Worker %d will handle source at local index %ld", worker,
                      source_index);
        }

        dc_partition_info_t info;
        info.local_sizes[0] = local_size_x;
        info.local_sizes[1] = local_size_y;
        info.local_sizes[2] = local_size_z;
        info.global_sizes[0] = global_sx;
        info.global_sizes[1] = global_sy;
        info.global_sizes[2] = global_sz;
        info.start_coords[0] = start_x;
        info.start_coords[1] = start_y;
        info.start_coords[2] = start_z;
        info.problem_sizes[0] = arguments.size_x;
        info.problem_sizes[1] = arguments.size_y;
        info.problem_sizes[2] = arguments.size_z;
        info.iterations = iterations;
        info.source_index = source_index;
        info.absorption_size = arguments.absorption_size;

        MPI_Send(&info, sizeof(dc_partition_info_t), MPI_BYTE, worker, 0, comm);
        dc_log_info(COORDINATOR, "Sent partition info to worker %d", worker);
      }
    }
  }
}

void dc_receive_and_write_results(dc_process_t coordinator_process,
                                  MPI_Comm comm, size_t global_sx,
                                  size_t global_sy, size_t global_sz,
                                  const char *output_file) {
  FILE *output = fopen(output_file, "wb");
  if (output == NULL) {
    dc_log_error(COORDINATOR, "Failed to open output file: %s", output_file);
    MPI_Finalize();
    exit(1);
  }

  size_t total_size = global_sx * global_sy * global_sz;

  float zero = 0.0f;
  fseek(output, (2 * total_size - 1) * sizeof(float), SEEK_SET);
  fwrite(&zero, sizeof(float), 1, output);

  size_t partition_size_x =
      (global_sx - 2 * STENCIL) / coordinator_process.topology[0];
  size_t partition_size_y =
      (global_sy - 2 * STENCIL) / coordinator_process.topology[1];
  size_t partition_size_z =
      (global_sz - 2 * STENCIL) / coordinator_process.topology[2];

  for (int worker_x = 0; worker_x < coordinator_process.topology[0];
       worker_x++) {
    for (int worker_y = 0; worker_y < coordinator_process.topology[1];
         worker_y++) {
      for (int worker_z = 0; worker_z < coordinator_process.topology[2];
           worker_z++) {
        int worker_coords[DIMENSIONS] = {worker_x, worker_y, worker_z};
        int worker_rank;
        MPI_Cart_rank(comm, worker_coords, &worker_rank);

        size_t worker_sizes[DIMENSIONS];
        float *pc, *qc;
        size_t worker_count;
        int need_free = 0;

        if (worker_rank == COORDINATOR) {
          memcpy(worker_sizes, coordinator_process.sizes,
                 sizeof(size_t) * DIMENSIONS);
          pc = coordinator_process.pc;
          qc = coordinator_process.qc;
          worker_count = dc_compute_count_from_sizes(worker_sizes);
        } else {
          MPI_Recv(worker_sizes, DIMENSIONS, MPI_UNSIGNED_LONG, worker_rank, 0,
                   comm, MPI_STATUS_IGNORE);
          worker_count = dc_compute_count_from_sizes(worker_sizes);

          pc = (float *)malloc(worker_count * sizeof(float));
          qc = (float *)malloc(worker_count * sizeof(float));
          if (pc == NULL || qc == NULL) {
            dc_log_error(COORDINATOR,
                         "OOM: could not allocate temp buffer for worker %d",
                         worker_rank);
            MPI_Finalize();
            exit(1);
          }
          need_free = 1;

          MPI_Recv(pc, worker_count, MPI_FLOAT, worker_rank, 0, comm,
                   MPI_STATUS_IGNORE);
          MPI_Recv(qc, worker_count, MPI_FLOAT, worker_rank, 0, comm,
                   MPI_STATUS_IGNORE);
        }

        // x is the contiguous dimension (dc_get_index_for_coordinates:
        // index = x + y*size_x + z*size_x*size_y), and worker_coords[0]
        // only offsets the global x by a constant for a fixed (y,z) row —
        // so as local_x sweeps a full row, both worker_index and
        // global_index advance one-for-one. One fwrite of the whole row
        // replaces one fwrite-per-voxel, cutting fseek+fwrite calls from
        // O(N^3) to O(N^2) (empirically ~764x fewer for N=1536) without
        // changing which bytes end up where.
        size_t row_len = worker_sizes[0] - 2 * STENCIL;
        for (size_t z = STENCIL; z < worker_sizes[2] - STENCIL; z++) {
          for (size_t y = STENCIL; y < worker_sizes[1] - STENCIL; y++) {
            size_t local_y = y - STENCIL;
            size_t local_z = z - STENCIL;
            size_t worker_row_start = dc_get_index_for_coordinates(
                STENCIL, y, z, worker_sizes[0], worker_sizes[1],
                worker_sizes[2]);
            size_t global_row_start = dc_get_index_for_coordinates(
                STENCIL + worker_coords[0] * partition_size_x,
                STENCIL + worker_coords[1] * partition_size_y + local_y,
                STENCIL + worker_coords[2] * partition_size_z + local_z,
                global_sx, global_sy, global_sz);

            fseek(output, global_row_start * sizeof(float), SEEK_SET);
            fwrite(&pc[worker_row_start], sizeof(float), row_len, output);

            fseek(output, (total_size + global_row_start) * sizeof(float),
                  SEEK_SET);
            fwrite(&qc[worker_row_start], sizeof(float), row_len, output);
          }
        }

        if (need_free) {
          free(pc);
          free(qc);
          dc_log_info(COORDINATOR,
                      "Received and wrote partition from worker %d",
                      worker_rank);
        }
      }
    }
  }

  fclose(output);
}
