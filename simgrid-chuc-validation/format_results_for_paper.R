# format_results_for_paper.R — joins real-campaign stats (5 reps,
# analysis/results_package/tables/part1_statistics.csv) with Level 1 and
# Level 2 simulated results, producing two paper-ready, richly-documented
# CSVs meant to be attached directly to a browser Claude session for
# drafting the results/discussion section and judging what needs a figure.
#
# Usage: conda activate r-analysis && Rscript simgrid-chuc-validation/format_results_for_paper.R
# Writes:
#   simgrid-chuc-validation/level1_results_formatted.csv
#   simgrid-chuc-validation/level2_results_formatted.csv
suppressMessages(library(tidyverse))

real <- read_csv("analysis/results_package/tables/part1_statistics.csv", show_col_types = FALSE) |>
  select(nodes, band, N, gpus,
         real_msamples_mean = mean_msamples, real_msamples_sd = sd_msamples,
         real_msamples_ci95 = ci95_msamples, real_msamples_min = min_msamples,
         real_msamples_max = max_msamples, real_msamples_n = n,
         real_me_mean = mean_me, real_me_sd = sd_me, real_me_ci95 = ci95_me,
         real_me_min = min_me, real_me_max = max_me)

band_norm <- function(x) recode(x, "1Gbps" = "1gbit", "10Gbps" = "10gbit", "25Gbps" = "25gbit",
                                 "1gbps" = "1gbit", "10gbps" = "10gbit", "25gbps" = "25gbit",
                                 .default = x)

# ---------------------------------------------------------------- LEVEL 1 --
lvl1 <- read_csv("simgrid-chuc-validation/fidelity_error.csv", show_col_types = FALSE) |>
  mutate(band = band_norm(band)) |>
  select(nodes, band, sim_msamples, sim_me,
         fidelity_error_throughput_pct, fidelity_error_me_pct)

# H200/chicoree configs (3n all bands + 4n_1gbit), collected 2026-08-13 on a
# DIFFERENT GPU model than the real campaign (A100) -- kept but clearly
# flagged, since Level 1's online-sampling method measures whatever real
# GPU executes the kernel; do not present these as same-hardware validation
# (see LEVEL2_FINDINGS.md sec 6.5). All rows with nodes %in% c(3,4) here are
# H200 UNLESS superseded by a reduced-N/A100 rerun -- see hardware column.
lvl1 <- lvl1 |>
  mutate(hardware = ifelse(nodes %in% c(3, 4), "H200 (chicoree, MISMATCHED vs real campaign's A100)", "A100 (chuc, same as real campaign)"),
         anchor_type = "original Table 3 anchor")

lvl1_out <- real |>
  inner_join(lvl1, by = c("nodes", "band")) |>
  mutate(
    notes = case_when(
      nodes == 2 & band == "1gbit" ~ "OUTLIER: -50% throughput / -48% ME, not root-caused; likely same low-bandwidth network-model gap as Level 2 (see notes on nodes>=2 @ 1gbit there)",
      nodes %in% c(3, 4) ~ "HARDWARE MISMATCH: sim measured on H200 (chicoree), real campaign measured on A100 (chuc) -- large errors here reflect GPU speed difference, not simulator inaccuracy. Do not present as validation.",
      TRUE ~ ""
    )
  ) |>
  arrange(nodes, factor(band, levels = c("1gbit", "10gbit", "25gbit")))

write_csv(lvl1_out, "simgrid-chuc-validation/level1_results_formatted.csv")

# Explicit placeholder rows for the 2 configs never run at all (4n @
# 10/25gbit, original anchor) -- so the CSV makes the gap visible instead
# of silently omitting them.
missing_lvl1 <- real |>
  filter(nodes == 4, band %in% c("10gbit", "25gbit")) |>
  anti_join(lvl1_out, by = c("nodes", "band")) |>
  mutate(sim_msamples = NA_real_, sim_me = NA_real_,
         fidelity_error_throughput_pct = NA_real_, fidelity_error_me_pct = NA_real_,
         hardware = NA_character_, anchor_type = NA_character_,
         notes = "NEVER RUN at the original anchor N=2176 -- GPU VRAM ceiling (see LEVEL2_FINDINGS.md sec 6.4). A reduced-N=1800 rerun on real A100 was planned for 2026-08-14.")

lvl1_out_full <- bind_rows(lvl1_out, missing_lvl1) |>
  arrange(nodes, factor(band, levels = c("1gbit", "10gbit", "25gbit")))
write_csv(lvl1_out_full, "simgrid-chuc-validation/level1_results_formatted.csv")

# ---------------------------------------------------------------- LEVEL 2 --
lvl2 <- read_csv("simgrid-chuc-validation/fidelity_error_level2.csv", show_col_types = FALSE) |>
  mutate(band = band_norm(band)) |>
  select(nodes, band, sim_msamples, sim_me,
         fidelity_error_throughput_pct, fidelity_error_me_pct) |>
  mutate(hardware = "A100 (real, real-hardware-extracted compute constant substituted for live sampling)",
         anchor_type = "original Table 3 anchor")

lvl2_out <- real |>
  inner_join(lvl2, by = c("nodes", "band")) |>
  mutate(
    # BUG FIX (caught before delivery): the "negative at 1gbit" pattern only
    # holds for nodes>=2 (real inter-node network traffic exists there).
    # nodes==1 has no inter-node MPI traffic at all, so it shows the SAME
    # large positive error at every band, 1gbit included -- an earlier
    # version of this logic incorrectly labeled node=1's 1gbit row as
    # "negative" too.
    notes = case_when(
      nodes >= 2 & band == "1gbit" ~ "throughput error large & NEGATIVE (-37% to -44%), ME error large & negative (-68% to -79%) -- consistent low-bandwidth network-model gap across node counts >=2 (see LEVEL2_FINDINGS.md sec 4)",
      TRUE ~ "throughput error large & POSITIVE (+139% to +274% for nodes>=2, +148-152% for node=1) -- compute-constant-substitution methodology gap dominates when network isn't the bottleneck, not a network-model issue (see LEVEL2_FINDINGS.md sec 4)"
    )
  ) |>
  arrange(nodes, factor(band, levels = c("1gbit", "10gbit", "25gbit")))

write_csv(lvl2_out, "simgrid-chuc-validation/level2_results_formatted.csv")

cat("Wrote:\n")
cat("  simgrid-chuc-validation/level1_results_formatted.csv (", nrow(lvl1_out_full), "rows,", sum(!is.na(lvl1_out_full$sim_msamples)), "with data)\n")
cat("  simgrid-chuc-validation/level2_results_formatted.csv (", nrow(lvl2_out), "rows)\n")
