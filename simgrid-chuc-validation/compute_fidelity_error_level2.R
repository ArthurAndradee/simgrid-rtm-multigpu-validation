# compute_fidelity_error_level2.R — formal fidelity-error table for Level 2
# (SimGrid with real A100 compute constants injected + original poti/
# Spadotto network calibration), across all 12 (nodes x band) configs.
#
# Fidelity error = 100 * (simulated - real) / real, for both throughput
# (msamples/s) and ME (masking effectiveness), matching the definition in
# papers/2026_chuc_gpu_validation/main.tex Sec 4.2 and the existing Level 1
# script (simgrid-chuc-validation/compute_fidelity_error.R).
#
# THROUGHPUT: both real and simulated use the SAME extraction -- the `*`
# line of dc.output, i.e. rank==COORDINATOR's own total_time as the
# denominator for global_msamples_per_s (src/main.c:224-232). Confirmed by
# reading analysis/gather_metrics.R:76 (`df[df$rank == "*", ]`), which is
# exactly what feeds mean_msamples in part1_statistics.csv -- so this is an
# apples-to-apples comparison, not a methodology mismatch (checked
# 2026-08-13, see conversation notes).
#
# ME: recomputed from dc.csv the same way analysis/masking_effectiveness.R
# computes it for the real campaign (window = [min MPI_Irecv Start, max
# MPI_Waitall End], comm_ratio = sum of clipped MPI state durations over all
# ranks / (window_length * n_ranks), ME = 1 - comm_ratio) -- reused here,
# not reimplemented differently, so it's the same metric on both sides.
#
# CAVEAT (documented, not fixed): only 1 run per (nodes, band) here, vs 5
# reps for the real campaign -- no confidence interval on the simulated
# side. The injected compute constants are themselves means of 5 real reps,
# so some of that variability is folded in but not propagated as an
# explicit CI.
#
# Usage: Rscript simgrid-chuc-validation/compute_fidelity_error_level2.R
# Writes simgrid-chuc-validation/fidelity_error_level2.csv

suppressMessages(library(tidyverse))

# Run from repo root, same convention as analysis/masking_effectiveness.R.
RESULTS_DIR <- "simgrid-chuc-validation/results_level2"
REAL_STATS_CSV <- "analysis/results_package/tables/part1_statistics.csv"

BAND_MAP <- c("1Gbps" = "1gbit", "10Gbps" = "10gbit", "25Gbps" = "25gbit")
NODES <- 1:4
BANDS <- c("1Gbps", "10Gbps", "25Gbps")

read_sim_throughput <- function(dc_output_path) {
  lines <- readLines(dc_output_path, warn = FALSE)
  header_idx <- grep("^rank,total_time,msamples_per_s", lines)
  if (length(header_idx) == 0) return(NA_real_)
  body <- lines[(header_idx[1] + 1):length(lines)]
  body <- body[grepl("^\\*,", body)]
  if (length(body) == 0) return(NA_real_)
  as.numeric(strsplit(body[1], ",")[[1]][3])
}

compute_me <- function(dc_csv_path) {
  df <- tryCatch(
    read_csv(dc_csv_path,
      col_names = c("Nature", "Container", "Type", "Start", "End", "Duration", "Imbrication", "Value"),
      col_types = cols(
        Nature = col_character(), Container = col_character(), Type = col_character(),
        Start = col_double(), End = col_double(), Duration = col_double(),
        Imbrication = col_double(), Value = col_character()
      ),
      trim_ws = TRUE, progress = FALSE
    ),
    error = function(e) NULL
  )
  if (is.null(df) || nrow(df) == 0) return(NA_real_)
  # Level 2 traces (this simulator/tracing config) log PMPI_-prefixed state
  # names (e.g. "PMPI_Irecv"), unlike the real campaign's plain "MPI_Irecv"
  # -- strip the profiling-layer prefix so both sides use the same matching
  # logic (found 2026-08-13: sim_me was NA for all 12 configs because the
  # filter never matched anything).
  df <- df |> mutate(Container = str_trim(Container), Value = str_remove(str_trim(Value), "^P(?=MPI_)"))

  window_start <- df |> filter(Value == "MPI_Irecv") |> pull(Start) |> min(na.rm = TRUE)
  window_end <- df |> filter(Value == "MPI_Waitall") |> pull(End) |> max(na.rm = TRUE)
  if (!is.finite(window_start) || !is.finite(window_end) || window_end <= window_start) return(NA_real_)

  n_ranks <- n_distinct(df$Container)
  window_length <- window_end - window_start

  comm_duration <- df |>
    filter(Start < window_end, End > window_start) |>
    mutate(
      clipped_start = pmax(Start, window_start),
      clipped_end = pmin(End, window_end),
      clipped_duration = pmax(0, clipped_end - clipped_start)
    ) |>
    pull(clipped_duration) |>
    sum(na.rm = TRUE)

  1 - (comm_duration / (window_length * n_ranks))
}

real <- read_csv(REAL_STATS_CSV, show_col_types = FALSE) |>
  select(nodes, band, real_msamples = mean_msamples, real_me = mean_me)

sim <- expand_grid(nodes = NODES, band_dir = BANDS) |>
  mutate(band = BAND_MAP[band_dir]) |>
  rowwise() |>
  mutate(
    dc_output = file.path(RESULTS_DIR, sprintf("%dn_%s", nodes, band_dir), "dc.output"),
    dc_csv = file.path(RESULTS_DIR, sprintf("%dn_%s", nodes, band_dir), "dc.csv"),
    sim_msamples = if (file.exists(dc_output)) read_sim_throughput(dc_output) else NA_real_,
    sim_me = if (file.exists(dc_csv)) compute_me(dc_csv) else NA_real_
  ) |>
  ungroup() |>
  select(nodes, band, sim_msamples, sim_me)

result <- real |>
  inner_join(sim, by = c("nodes", "band")) |>
  mutate(
    fidelity_error_throughput_pct = 100 * (sim_msamples - real_msamples) / real_msamples,
    fidelity_error_me_pct = 100 * (sim_me - real_me) / real_me
  ) |>
  arrange(nodes, factor(band, levels = c("1gbit", "10gbit", "25gbit")))

dir.create("simgrid-chuc-validation", showWarnings = FALSE)
write_csv(result, "simgrid-chuc-validation/fidelity_error_level2.csv")

cat("Wrote simgrid-chuc-validation/fidelity_error_level2.csv\n\n")
print(result, n = Inf, width = Inf)
