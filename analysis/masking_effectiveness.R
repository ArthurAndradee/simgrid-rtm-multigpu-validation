# Masking Effectiveness metric, as defined in papers/2026_CARLA/CARLA_SimGrid_Ghost.org
# ("Evaluation Methodology and Masking Effectiveness Metric"):
#
#   1. Execution window = [min Start of MPI_Irecv, max End of MPI_Waitall],
#      taken across all ranks.
#   2. Clip every MPI state event to that window.
#   3. Communication ratio = (sum of clipped MPI state durations, all ranks)
#                             / (window length * number of ranks)
#   4. Masking Effectiveness = 1 - Communication ratio.
#
# Unlike the CARLA paper (SimGrid/SMPI simulated traces), this script reads
# dc.csv files produced by our real-hardware campaign (Akypuera -> pj_dump),
# which use the same Paje-derived schema:
#   Nature, Container, Type, Start, End, Duration, Imbrication, Value
#
# Usage:
#   Rscript analysis/masking_effectiveness.R [results_dir] [output_csv]
#
# Defaults: results_dir = "g5k/results", output_csv = "analysis/masking_effectiveness.csv"

suppressMessages(library(tidyverse))

args <- commandArgs(trailingOnly = TRUE)
results_dir <- if (length(args) >= 1) args[1] else "g5k/results"
output_csv <- if (length(args) >= 2) args[2] else "analysis/masking_effectiveness.csv"

if (!dir.exists(results_dir)) {
  stop(paste("Directory not found:", results_dir))
}

dc_csv_files <- list.files(
  path = results_dir, pattern = "^dc\\.csv$",
  recursive = TRUE, full.names = TRUE
)

if (length(dc_csv_files) == 0) {
  stop(paste("No dc.csv files found under", results_dir))
}

# Parses "results/<experiment_id>/rep<N>/dc.csv" (also matches g5k/results/... ,
# and full_*/rep1 ground-truth dirs, which have no rep number > 1 but the same shape).
parse_experiment_path <- function(path) {
  m <- str_match(path, "/([^/]+)/rep([0-9]+)/dc\\.csv$")
  list(experiment_id = m[2], rep = as.integer(m[3]))
}

compute_masking_effectiveness <- function(dc_csv_path) {
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

  if (is.null(df) || nrow(df) == 0) {
    return(NULL)
  }

  df <- df |> mutate(Container = str_trim(Container), Value = str_trim(Value))

  window_start <- df |> filter(Value == "MPI_Irecv") |> pull(Start) |> min(na.rm = TRUE)
  window_end <- df |> filter(Value == "MPI_Waitall") |> pull(End) |> max(na.rm = TRUE)

  if (!is.finite(window_start) || !is.finite(window_end) || window_end <= window_start) {
    return(NULL)
  }

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

  comm_ratio <- comm_duration / (window_length * n_ranks)
  masking_effectiveness <- 1 - comm_ratio

  tibble(
    n_ranks = n_ranks,
    window_length_s = window_length,
    comm_duration_s = comm_duration,
    comm_ratio = comm_ratio,
    masking_effectiveness = masking_effectiveness
  )
}

results <- map_dfr(dc_csv_files, function(path) {
  parsed <- parse_experiment_path(path)
  if (is.na(parsed$experiment_id)) {
    warning(paste("Could not parse path structure for:", path))
    return(NULL)
  }
  metrics <- compute_masking_effectiveness(path)
  if (is.null(metrics)) {
    warning(paste("Skipping (no usable MPI_Irecv/MPI_Waitall window):", path))
    return(NULL)
  }
  bind_cols(tibble(experiment_id = parsed$experiment_id, rep = parsed$rep), metrics)
})

if (nrow(results) == 0) {
  stop("No experiment produced a valid Masking Effectiveness value.")
}

results <- results |> arrange(experiment_id, rep)

dir.create(dirname(output_csv), showWarnings = FALSE, recursive = TRUE)
write_csv(results, output_csv)

cat(sprintf("Wrote %d rows to %s\n\n", nrow(results), output_csv))
print(
  results |>
    group_by(experiment_id) |>
    summarise(
      reps = n(),
      mean_masking_effectiveness = mean(masking_effectiveness),
      .groups = "drop"
    ) |>
    arrange(desc(mean_masking_effectiveness)),
  n = Inf
)
