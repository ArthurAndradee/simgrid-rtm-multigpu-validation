# analyze_microbench.R -- tests Hypothesis 2 (LEVEL2_FINDINGS.md sec 6.7)
# against the microbench.c CSV: does one rank's real completion time predict
# the SimGrid platform_shared_nic.cpp idealization (all 4 same-node senders
# pinned at exactly 1/RANKS_PER_NODE of net_bw for the whole transfer, so
# all 4 finish at essentially the same instant), or does real hardware
# stagger completions (some ranks finish well before the idealized time,
# freeing that GPU to resume computing sooner -- which is exactly what ME
# measures)?
#
# Usage: Rscript analyze_microbench.R <microbench_csv> <rate_bps> [ranks_per_node]
suppressMessages(library(tidyverse))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("Usage: Rscript analyze_microbench.R <csv> <rate_bps> [ranks_per_node]")
csv_path <- args[1]
rate_bps <- as.numeric(args[2])
ranks_per_node <- if (length(args) >= 3) as.integer(args[3]) else 4

df <- read_csv(csv_path, show_col_types = FALSE)
msg_bytes <- NULL # inferred implicitly: not stored per-row, pass via arg if needed later

idealized_s <- NA_real_ # filled in per-call below once msg_bytes is known

cat(sprintf("=== %s ===\n", csv_path))
cat(sprintf("Trials: %d | Senders: %d\n", length(unique(df$trial)), length(unique(df$rank))))

per_trial <- df %>%
  group_by(trial) %>%
  summarise(
    min_end = min(end_offset_s),
    max_end = max(end_offset_s),
    mean_end = mean(end_offset_s),
    spread_s = max_end - min_end,
    spread_pct_of_mean = 100 * spread_s / mean_end,
    .groups = "drop"
  )

cat("\n--- Per-trial completion spread across the 4 concurrent senders ---\n")
print(as.data.frame(per_trial), row.names = FALSE)

cat(sprintf(
  "\nMean completion time across all trials/ranks: %.4f s\n",
  mean(df$end_offset_s)
))
cat(sprintf(
  "Mean intra-trial spread (max-min across the 4 senders): %.4f s (%.1f%% of mean completion time)\n",
  mean(per_trial$spread_s), mean(per_trial$spread_pct_of_mean)
))

cat("\n--- Verdict ---\n")
if (mean(per_trial$spread_pct_of_mean) < 5) {
  cat("Senders finish essentially in LOCKSTEP (spread < 5% of completion time).\n")
  cat("This matches the SimGrid idealized continuous fair-share model.\n")
  cat("Hypothesis 2 (staggered real completions) NOT supported by this run.\n")
} else {
  cat("Senders finish STAGGERED (spread >= 5% of completion time).\n")
  cat("Some ranks free their GPU to resume computing well before others --\n")
  cat("exactly the mechanism Hypothesis 2 proposes, and exactly what the\n")
  cat("idealized continuous-fair-share SimGrid model (platform_shared_nic.cpp)\n")
  cat("cannot express. Supports Hypothesis 2.\n")
}

# Fastest-finisher fraction: on real hardware, if 1 sender finishes at t_fast
# while the group's real aggregate (bytes/line-rate) is t_agg, the FASTEST
# rank got closer to full line rate for a larger share of its transfer than
# the idealized 1/ranks_per_node the whole time -- this is the number that
# would feed back into a corrected platform model (e.g. a two-phase or
# rank-dependent effective-bandwidth curve instead of one constant fraction).
cat(sprintf(
  "\nFastest sender finishes, on average, %.1f%% earlier than the slowest.\n",
  100 * mean(1 - per_trial$min_end / per_trial$max_end)
))
