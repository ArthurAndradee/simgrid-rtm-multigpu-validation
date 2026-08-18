# Generic per-experiment_id statistical aggregation: mean, sd, and a 95% CI
# (t-distribution, appropriate for n<=5 reps) for every numeric metric column
# found in the input CSV. Neither this repo's own scripts nor the ones
# inherited from the original Spadotto thesis/paper compute a confidence
# interval anywhere; the campaign's checkpoint/reporting layer only ever
# reported means.
#
# Usage:
#   Rscript analysis/aggregate_stats.R <input_csv> [output_csv]
#
# <input_csv> must have an "experiment_id" column (a "rep" column is
# optional/ignored) plus one or more numeric metric columns. Works directly
# on the outputs of gather_metrics.R (throughput_raw.csv) and
# masking_effectiveness.R (masking_effectiveness.csv).

suppressMessages(library(tidyverse))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: Rscript analysis/aggregate_stats.R <input_csv> [output_csv]")
}
input_csv <- args[1]
output_csv <- if (length(args) >= 2) args[2] else sub("\\.csv$", "_summary.csv", input_csv)

if (!file.exists(input_csv)) {
  stop(paste("File not found:", input_csv))
}

df <- read_csv(input_csv, show_col_types = FALSE)

if (!"experiment_id" %in% names(df)) {
  stop("Input CSV must have an 'experiment_id' column.")
}

metric_cols <- df |>
  select(-experiment_id, -any_of("rep")) |>
  select(where(is.numeric)) |>
  names()

if (length(metric_cols) == 0) {
  stop("No numeric metric columns found besides experiment_id/rep.")
}

# 95% CI half-width via the t-distribution: appropriate for the campaign's
# n=5 reps (or fewer, for partially-completed experiment_ids), where a
# normal-approximation CI would understate uncertainty.
ci95_halfwidth <- function(x) {
  n <- sum(!is.na(x))
  if (n < 2) {
    return(NA_real_)
  }
  se <- sd(x, na.rm = TRUE) / sqrt(n)
  se * qt(0.975, df = n - 1)
}

summarise_metric <- function(df, metric) {
  df |>
    group_by(experiment_id) |>
    summarise(
      metric = metric,
      n = sum(!is.na(.data[[metric]])),
      mean = mean(.data[[metric]], na.rm = TRUE),
      sd = sd(.data[[metric]], na.rm = TRUE),
      ci95_halfwidth = ci95_halfwidth(.data[[metric]]),
      ci95_low = mean - ci95_halfwidth,
      ci95_high = mean + ci95_halfwidth,
      .groups = "drop"
    )
}

result <- map_dfr(metric_cols, ~ summarise_metric(df, .x)) |>
  relocate(metric, .after = experiment_id) |>
  arrange(metric, experiment_id)

dir.create(dirname(output_csv), showWarnings = FALSE, recursive = TRUE)
write_csv(result, output_csv)

cat(sprintf("Wrote %d rows (%d experiment_ids x %d metrics) to %s\n\n", nrow(result), n_distinct(result$experiment_id), length(metric_cols), output_csv))
print(result, n = Inf)
