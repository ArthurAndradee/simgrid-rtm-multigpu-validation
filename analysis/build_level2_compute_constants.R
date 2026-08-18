# Builds the Level 2 "real A100 compute constant" table: mean per-rank,
# per-iteration CUDA kernel time (dc_compute_boundaries + dc_compute_interior),
# extracted from the real campaign's 25gbit reps (least network contention ->
# cleanest signal) for each of the 4 anchor node counts. Compute time should
# be bandwidth-independent (same subdomain, same GPU work regardless of link
# speed), so this one extraction per node count is reused for all 3
# bandwidths (1/10/25gbit) of that node count in the Level 2 simulation --
# see analysis/extract_kernel_time.R for why the extraction itself is valid.
#
# Usage: Rscript analysis/build_level2_compute_constants.R
# Writes analysis/level2_compute_constants.csv:
#   nodes, rank, n_reps, n_iter, mean_kernel_s, median_kernel_s, sd_kernel_s

suppressMessages(library(tidyverse))
source("analysis/kernel_time_lib.R")

ANCHOR_DIR <- c(
  `1` = "bench_25gbit_1n_4g_N1344",
  `2` = "bench_25gbit_2n_8g_N1728",
  `3` = "bench_25gbit_3n_12g_N1920",
  `4` = "bench_25gbit_4n_16g_N2176"
)

results <- map_dfr(names(ANCHOR_DIR), function(nodes_str) {
  nodes <- as.integer(nodes_str)
  dir <- file.path("g5k/results", ANCHOR_DIR[[nodes_str]])
  files <- Sys.glob(file.path(dir, "rep*/dc.csv"))
  if (length(files) == 0) stop(paste("No dc.csv files found under", dir))

  extract_kernel_times_from_files(files) |>
    filter(iteration > 1) |> # drop warm-up (first-touch CUDA context/JIT) iteration
    mutate(nodes = nodes, rank = as.integer(str_remove(Container, "rank")))
})

per_rank <- results |>
  group_by(nodes, rank) |>
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
  arrange(nodes, rank)

write_csv(per_rank, "analysis/level2_compute_constants.csv")

cat("Wrote analysis/level2_compute_constants.csv\n\n")
print(per_rank, n = Inf)

cat("\n=== Per-topology summary (mean across ranks) ===\n")
print(
  per_rank |>
    group_by(nodes) |>
    summarise(
      n_ranks = n(),
      mean_kernel_ms = mean(mean_kernel_s) * 1000,
      min_rank_ms = min(mean_kernel_s) * 1000,
      max_rank_ms = max(mean_kernel_s) * 1000,
      spread_pct = 100 * (max(mean_kernel_s) - min(mean_kernel_s)) / mean(mean_kernel_s),
      .groups = "drop"
    ),
  n = Inf
)
