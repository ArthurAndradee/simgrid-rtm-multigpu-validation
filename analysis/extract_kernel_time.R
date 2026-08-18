# Extracts pure CUDA kernel time (dc_compute_boundaries + dc_compute_interior)
# per iteration, per rank, from the real-campaign dc.csv traces -- WITHOUT
# running any new benchmark. This is possible because:
#
#   - dc.csv has NO explicit "Compute" state; only MPI_* call states are
#     logged (Irecv, Isend, Waitall, ...).
#   - src/worker.c's per-iteration loop is:
#       MPI_Irecv (x k)  ->  dc_compute_boundaries()  ->  MPI_Isend (x k)
#       -> dc_compute_interior()  ->  MPI_Waitall(recv)  -> [halo insert,
#       swap]  ->  MPI_Waitall(send)
#   - src/cuda_propagate.cu calls cudaDeviceSynchronize() right after the
#     kernel launch inside dc_propagate(), so the host thread genuinely
#     blocks for the kernel's real execution time.
#   - Therefore the UNINSTRUMENTED gap between (end of last Irecv, start of
#     first Isend) is exactly dc_compute_boundaries()'s wall time, and the
#     gap between (end of last Isend, start of first Waitall) is exactly
#     dc_compute_interior()'s wall time. Their sum is the real, measured,
#     per-iteration CUDA kernel time on the actual A100 hardware used in
#     the campaign -- the same role a standalone kernel microbenchmark
#     would have served, extracted from already-collected data instead.
#
# Usage: Rscript analysis/extract_kernel_time.R <dc.csv path> [dc.csv path ...]
# Prints one row per (rank, iteration) with compute_boundaries_s,
# compute_interior_s, kernel_time_s.

suppressMessages(library(tidyverse))
source("analysis/kernel_time_lib.R")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) stop("Usage: Rscript extract_kernel_time.R <dc.csv> [...]")

all_results <- extract_kernel_times_from_files(args)

write_csv(all_results, "/tmp/kernel_time_raw.csv")

cat(sprintf("Parsed %d (rank, iteration) rows from %d file(s)\n\n", nrow(all_results), length(args)))

cat("=== Per-rank summary (all iterations) ===\n")
print(
  all_results |>
    group_by(Container) |>
    summarise(
      n_iter = n(),
      mean_kernel_ms = mean(kernel_time_s) * 1000,
      median_kernel_ms = median(kernel_time_s) * 1000,
      sd_kernel_ms = sd(kernel_time_s) * 1000,
      min_kernel_ms = min(kernel_time_s) * 1000,
      max_kernel_ms = max(kernel_time_s) * 1000,
      .groups = "drop"
    ),
  n = Inf
)

cat("\n=== Per-rank summary, excluding iteration 1 (warm-up) ===\n")
print(
  all_results |>
    filter(iteration > 1) |>
    group_by(Container) |>
    summarise(
      n_iter = n(),
      mean_kernel_ms = mean(kernel_time_s) * 1000,
      median_kernel_ms = median(kernel_time_s) * 1000,
      sd_kernel_ms = sd(kernel_time_s) * 1000,
      .groups = "drop"
    ),
  n = Inf
)

cat("\n=== Overall (all ranks, all files, excluding iteration 1) ===\n")
overall <- all_results |> filter(iteration > 1)
cat(sprintf(
  "n = %d, mean = %.4f ms, median = %.4f ms, sd = %.4f ms, cv = %.2f%%\n",
  nrow(overall), mean(overall$kernel_time_s) * 1000, median(overall$kernel_time_s) * 1000,
  sd(overall$kernel_time_s) * 1000, 100 * sd(overall$kernel_time_s) / mean(overall$kernel_time_s)
))
