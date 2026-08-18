# Builds analysis/dossie_full_join.csv: the single canonical table joining
# throughput, Masking Effectiveness and CSV metadata (band/nodes/GPUs/topology/N)
# per experiment_id, restricted to checkpoint-confirmed repetitions.
#
# This is the exact join used to build analysis/DOSSIE_RESULTADOS.md and
# consumed by every script in results/scripts/ -- previously run ad hoc
# (interactively) while assembling that dossier; extracted here so it's
# reproducible with a single command instead of only existing in chat history.
#
# Inputs (regenerate first if stale -- see analysis/DOSSIE_RESULTADOS.md):
#   - g5k/csv/experimentos.csv               (static, versioned)
#   - analysis/throughput_raw.csv            (Rscript analysis/gather_metrics.R)
#   - analysis/masking_effectiveness.csv     (Rscript analysis/masking_effectiveness.R)
#
# Usage:
#   Rscript analysis/build_dossier_join.R [output_csv]
# Default output: analysis/dossie_full_join.csv
suppressMessages(library(tidyverse))

args <- commandArgs(trailingOnly = TRUE)
output_csv <- if (length(args) >= 1) args[1] else "analysis/dossie_full_join.csv"

for (f in c("g5k/csv/experimentos.csv", "analysis/throughput_raw.csv", "analysis/masking_effectiveness.csv")) {
  if (!file.exists(f)) stop(paste("Missing input:", f, "-- see file header for how to regenerate it."))
}

csv <- read_csv("g5k/csv/experimentos.csv", show_col_types = FALSE) |>
  mutate(experiment_id = paste0("bench_", Banda_Rede, "_", Num_Nos, "n_", Num_GPUs, "g_N", Tamanho_Global_N))

thr <- read_csv("analysis/throughput_raw.csv", show_col_types = FALSE)
me <- read_csv("analysis/masking_effectiveness.csv", show_col_types = FALSE)

thr_done <- thr |> filter(checkpoint_status == "done")

reps_done <- thr_done |> group_by(experiment_id) |> summarise(reps_done = n(), .groups = "drop")

thr_stats <- thr_done |>
  group_by(experiment_id) |>
  summarise(
    mean_total_time = mean(total_time), sd_total_time = sd(total_time),
    mean_msamples = mean(msamples_per_s), sd_msamples = sd(msamples_per_s),
    .groups = "drop"
  )

me_stats <- me |>
  filter(experiment_id %in% thr_done$experiment_id) |>
  group_by(experiment_id) |>
  summarise(
    reps_me = n(), mean_me = mean(masking_effectiveness), sd_me = sd(masking_effectiveness),
    .groups = "drop"
  )

ci95 <- function(sd, n) ifelse(is.na(sd) | n < 2, NA_real_, sd / sqrt(n) * qt(0.975, df = n - 1))

full <- reps_done |>
  left_join(thr_stats, by = "experiment_id") |>
  left_join(me_stats, by = "experiment_id") |>
  left_join(csv |> select(experiment_id, Banda_Rede, Num_Nos, Num_GPUs, Topologia_MPI, Tamanho_Global_N), by = "experiment_id") |>
  mutate(
    ci95_total_time = ci95(sd_total_time, reps_done),
    ci95_msamples = ci95(sd_msamples, reps_done),
    ci95_me = ci95(sd_me, reps_me),
    cv_msamples_pct = 100 * sd_msamples / mean_msamples
  ) |>
  arrange(Num_Nos, Banda_Rede, Tamanho_Global_N)

write_csv(full, output_csv)
message(sprintf("Wrote %d rows to %s", nrow(full), output_csv))
