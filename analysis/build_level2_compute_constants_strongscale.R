# Per-TOPOLOGY Level 2 compute constants, built from the strong-scaling
# campaign traces (g5k/results/strongscale_native_*). The original
# analysis/build_level2_compute_constants.R keys constants by (nodes, rank)
# only, sampled from one fixed MPI_Dims_create topology per node count;
# this version keys them by partition shape as well.
#
# Same extraction as the original (kernel_time_lib.R: uninstrumented gaps
# between MPI calls = cudaDeviceSynchronize()'d kernel time), same warm-up
# drop (iteration 1), keyed by (experiment_id, rank) instead.
#
# np=1 has no MPI calls, so the gap-based extraction yields nothing; its
# constants are derived from dc.output instead (total_time / iterations,
# all attributed to interior -- there are no boundaries to exchange).
#
# Usage: Rscript analysis/build_level2_compute_constants_strongscale.R
# Output: analysis/level2_compute_constants_strongscale.csv
suppressMessages(library(tidyverse))
source("analysis/kernel_time_lib.R")

plan <- read_csv("g5k/csv/strongscale_experiments.csv", show_col_types = FALSE)
ITERATIONS <- 100

per_config <- map_dfr(seq_len(nrow(plan)), function(k) {
  cfg <- plan[k, ]
  files <- Sys.glob(file.path("g5k/results", cfg$experiment_id, "rep*/dc.csv"))
  files <- files[file.size(files) > 0]
  if (length(files) == 0) return(NULL)

  if (cfg$np == 1) {
    outs <- Sys.glob(file.path("g5k/results", cfg$experiment_id, "rep*/dc.output"))
    tt <- map_dbl(outs, ~ as.numeric(str_split(grep("^0,", readLines(.x), value = TRUE)[1], ",")[[1]][2]))
    return(tibble(
      experiment_id = cfg$experiment_id, rank = 0L, n_reps = length(tt),
      n_iter = length(tt) * ITERATIONS,
      mean_boundaries_s = 0, mean_interior_s = mean(tt) / ITERATIONS,
      mean_bookkeeping_s = 0, mean_kernel_s = mean(tt) / ITERATIONS,
      median_kernel_s = median(tt) / ITERATIONS, sd_kernel_s = sd(tt) / ITERATIONS
    ))
  }

  extract_kernel_times_from_files(files) |>
    filter(iteration > 1) |>
    mutate(rank = as.integer(str_remove(Container, "rank"))) |>
    group_by(rank) |>
    summarise(
      n_reps = n_distinct(source_file),
      n_iter = n(),
      mean_boundaries_s = mean(compute_boundaries_s),
      mean_interior_s = mean(compute_interior_s),
      mean_bookkeeping_s = mean(bookkeeping_s),
      mean_kernel_s = mean(kernel_time_s),
      median_kernel_s = median(kernel_time_s),
      sd_kernel_s = sd(kernel_time_s),
      .groups = "drop"
    ) |>
    mutate(experiment_id = cfg$experiment_id, .before = 1)
})

out <- per_config |>
  inner_join(plan |> select(experiment_id, np, dims_str, local_x, local_y, local_z),
             by = "experiment_id") |>
  relocate(np, dims_str, local_x, local_y, local_z, .after = experiment_id) |>
  arrange(np, experiment_id, rank)

write_csv(out, "analysis/level2_compute_constants_strongscale.csv")
cat(sprintf("Wrote %d rows (%d configs) to analysis/level2_compute_constants_strongscale.csv\n\n",
            nrow(out), n_distinct(out$experiment_id)))

# Sanity: every config must have exactly np ranks and 5 reps.
check <- out |> group_by(experiment_id, np) |>
  summarise(ranks = n(), min_reps = min(n_reps), .groups = "drop") |>
  filter(ranks != np | min_reps < 5)
if (nrow(check) > 0) { cat("WARNING: incomplete configs:\n"); print(check, n = Inf) }

cat("=== Per-config mean kernel time per iteration (ms), by np ===\n")
print(out |> group_by(np, dims_str, local_x) |>
  summarise(kernel_ms = 1000 * mean(mean_kernel_s), .groups = "drop") |>
  group_by(np) |>
  summarise(configs = n(), min_ms = min(kernel_ms), max_ms = max(kernel_ms),
            spread_x = max_ms / min_ms, .groups = "drop"), n = Inf)
