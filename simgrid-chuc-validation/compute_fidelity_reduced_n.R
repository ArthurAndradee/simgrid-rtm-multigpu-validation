# compute_fidelity_reduced_n.R — fidelity error for the 2026-08-14/17
# reduced-N=1800 session: REAL (genuine distributed MPI, results_reduced_n_real/)
# vs SIMULATED (SMPI, results_reduced_n/), same N, same hardware (A100).
#
# NOT comparable to Table 3 (different N) -- see REDUCED_N_RUNBOOK.md.
#
# Usage: conda activate r-analysis && Rscript simgrid-chuc-validation/compute_fidelity_reduced_n.R
suppressMessages(library(tidyverse))

read_throughput <- function(dc_output_path) {
  lines <- readLines(dc_output_path, warn = FALSE)
  body <- lines[grepl("^\\*,", lines)]
  if (length(body) == 0) return(NA_real_)
  as.numeric(strsplit(body[1], ",")[[1]][3])
}

compute_me <- function(dc_csv_path) {
  df <- tryCatch(
    read_csv(dc_csv_path,
      col_names = c("Nature", "Container", "Type", "Start", "End", "Duration", "Imbrication", "Value"),
      col_types = cols(.default = col_character(), Start = col_double(), End = col_double(), Duration = col_double()),
      trim_ws = TRUE, progress = FALSE
    ),
    error = function(e) NULL
  )
  if (is.null(df) || nrow(df) == 0) return(NA_real_)
  df <- df |> mutate(Container = str_trim(Container), Value = str_remove(str_trim(Value), "^P(?=MPI_)"))
  window_start <- df |> filter(Value == "MPI_Irecv") |> pull(Start) |> min(na.rm = TRUE)
  window_end <- df |> filter(Value == "MPI_Waitall") |> pull(End) |> max(na.rm = TRUE)
  if (!is.finite(window_start) || !is.finite(window_end) || window_end <= window_start) return(NA_real_)
  n_ranks <- n_distinct(df$Container)
  window_length <- window_end - window_start
  comm_duration <- df |>
    filter(Start < window_end, End > window_start) |>
    mutate(clipped_start = pmax(Start, window_start), clipped_end = pmin(End, window_end),
           clipped_duration = pmax(0, clipped_end - clipped_start)) |>
    pull(clipped_duration) |> sum(na.rm = TRUE)
  1 - (comm_duration / (window_length * n_ranks))
}

NODES <- c(3, 4)
BANDS_REAL <- c("1gbit", "10gbit", "25gbit")
BANDS_SIM <- c("1Gbps", "10Gbps", "25Gbps")

rows <- list()
i <- 1
for (nodes in NODES) {
  for (bi in seq_along(BANDS_REAL)) {
    band_real <- BANDS_REAL[bi]; band_sim <- BANDS_SIM[bi]
    real_dir <- sprintf("simgrid-chuc-validation/results_reduced_n_real/%dn_%s", nodes, band_real)
    sim_dir <- sprintf("simgrid-chuc-validation/results_reduced_n/%dn_%s", nodes, band_sim)
    real_out <- file.path(real_dir, "dc.output"); real_csv <- file.path(real_dir, "dc.csv")
    sim_out <- file.path(sim_dir, "dc.output"); sim_csv <- file.path(sim_dir, "dc.csv")
    rows[[i]] <- tibble(
      nodes = nodes, band = band_real, N = 1800,
      real_msamples = if (file.exists(real_out)) read_throughput(real_out) else NA_real_,
      real_me = if (file.exists(real_csv)) compute_me(real_csv) else NA_real_,
      sim_msamples = if (file.exists(sim_out)) read_throughput(sim_out) else NA_real_,
      sim_me = if (file.exists(sim_csv)) compute_me(sim_csv) else NA_real_
    )
    i <- i + 1
  }
}

result <- bind_rows(rows) |>
  mutate(
    fidelity_error_throughput_pct = 100 * (sim_msamples - real_msamples) / real_msamples,
    fidelity_error_me_pct = 100 * (sim_me - real_me) / real_me,
    hardware = "A100 (both sides, chuc-1/4/6/8)",
    anchor_type = "REDUCED N=1800 (not Table 3 anchor)"
  ) |>
  arrange(nodes, factor(band, levels = BANDS_REAL))

write_csv(result, "simgrid-chuc-validation/fidelity_error_reduced_n.csv")
cat("Wrote simgrid-chuc-validation/fidelity_error_reduced_n.csv\n\n")
print(result, n = Inf, width = Inf)
