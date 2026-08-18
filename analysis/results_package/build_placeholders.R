# Emits every placeholder value mechanically from the already-written Part
# 1/2/3 tables. No value is typed by hand -- every number here is a direct
# read of a CSV cell, only reformatted for presentation.
suppressMessages(library(tidyverse))

tab_dir <- "analysis/results_package/tables"
out_file <- "analysis/results_package/tables/part6_placeholders.md"

part1 <- read_csv(file.path(tab_dir, "part1_statistics.csv"), show_col_types = FALSE)
part2 <- read_csv(file.path(tab_dir, "part2_band_gains.csv"), show_col_types = FALSE)
part3_raw <- read_csv(file.path(tab_dir, "part3_scaling_raw.csv"), show_col_types = FALSE)
part3_steps <- read_csv(file.path(tab_dir, "part3_scaling_steps.csv"), show_col_types = FALSE)
part3_slopes <- read_csv(file.path(tab_dir, "part3_scaling_slopes.csv"), show_col_types = FALSE)

L <- c()
add <- function(tag, val) {
  if (identical(tag, "SECTION")) {
    L <<- c(L, "", val, "")
  } else {
    L <<- c(L, sprintf("<%s> = %s", tag, val))
  }
}
n2 <- function(x) sprintf("%.2f", x)
n1 <- function(x) sprintf("%.1f", x)
n3 <- function(x) sprintf("%.3f", x)

add("SECTION", "=== Throughput e Masking Effectiveness por (nós, banda) ===")
for (i in seq_len(nrow(part1))) {
  r <- part1[i, ]
  tag <- sprintf("%dnode_%s", r$nodes, r$band)
  add(sprintf("throughput_%s", tag), sprintf("%s MSamples/s", n1(r$mean_msamples)))
  add(sprintf("throughput_ci95_%s", tag), sprintf("±%s MSamples/s", n2(r$ci95_msamples)))
  add(sprintf("throughput_sd_%s", tag), sprintf("%s MSamples/s", n2(r$sd_msamples)))
  add(sprintf("throughput_min_%s", tag), sprintf("%s MSamples/s", n1(r$min_msamples)))
  add(sprintf("throughput_max_%s", tag), sprintf("%s MSamples/s", n1(r$max_msamples)))
  add(sprintf("throughput_cv_%s", tag), sprintf("%s%%", n2(r$cv_msamples_pct)))
  add(sprintf("total_time_%s", tag), sprintf("%s s", n1(r$mean_total_time_s)))
  add(sprintf("total_time_ci95_%s", tag), sprintf("±%s s", n2(r$ci95_total_time_s)))
  add(sprintf("masking_eff_%s", tag), sprintf("%s%%", n1(100 * r$mean_me)))
  add(sprintf("masking_eff_ci95_%s", tag), sprintf("±%s pp", n2(100 * r$ci95_me)))
  add(sprintf("masking_eff_sd_%s", tag), sprintf("%s pp", n2(100 * r$sd_me)))
  add(sprintf("masking_eff_min_%s", tag), sprintf("%s%%", n1(100 * r$min_me)))
  add(sprintf("masking_eff_max_%s", tag), sprintf("%s%%", n1(100 * r$max_me)))
  add(sprintf("masking_eff_cv_%s", tag), sprintf("%s%%", n2(r$cv_me_pct)))
  add(sprintf("n_reps_%s", tag), sprintf("%d", r$n))
}

add("SECTION", "=== Ganhos por transicao de banda, por topologia (Parte 2) ===")
for (i in seq_len(nrow(part2))) {
  r <- part2[i, ]
  tag <- sprintf("%dnode", r$nodes)
  add(sprintf("relative_gain_1to10_thr_%s", tag), sprintf("%s%%", n1(r$thr_gain_1to10_pct)))
  add(sprintf("relative_gain_10to25_thr_%s", tag), sprintf("%s%%", n1(r$thr_gain_10to25_pct)))
  add(sprintf("relative_gain_1to25_thr_%s", tag), sprintf("%s%%", n1(r$thr_gain_1to25_pct)))
  add(sprintf("diminishing_returns_thr_%s", tag), sprintf("%s%%", n1(r$thr_diminishing_returns_pct)))
  add(sprintf("relative_gain_1to10_me_%s", tag), sprintf("%s%%", n1(r$me_gain_1to10_pct)))
  add(sprintf("relative_gain_10to25_me_%s", tag), sprintf("%s%%", n1(r$me_gain_10to25_pct)))
  add(sprintf("relative_gain_1to25_me_%s", tag), sprintf("%s%%", n1(r$me_gain_1to25_pct)))
  add(sprintf("diminishing_returns_me_%s", tag), sprintf("%s%%", n1(r$me_diminishing_returns_pct)))
  add(sprintf("gain_1to10_me_pp_%s", tag), sprintf("%s pp", n1(r$me_gain_1to10_pp)))
  add(sprintf("gain_10to25_me_pp_%s", tag), sprintf("%s pp", n1(r$me_gain_10to25_pp)))
  add(sprintf("gain_1to25_me_pp_%s", tag), sprintf("%s pp", n1(r$me_gain_1to25_pp)))
}

add("SECTION", "=== Throughput por GPU (Parte 3) ===")
for (i in seq_len(nrow(part3_raw))) {
  r <- part3_raw[i, ]
  add(sprintf("throughput_per_gpu_%dnode_%s", r$nodes, r$band), sprintf("%s MSamples/s", n1(r$throughput_per_gpu)))
}

add("SECTION", "=== Variacao passo-a-passo entre escalas (Parte 3) ===")
for (i in seq_len(nrow(part3_steps))) {
  r <- part3_steps[i, ]
  step_tag <- str_replace(r$step, "->", "to")
  add(sprintf("thr_per_gpu_pctchange_%s_%s", step_tag, r$band), sprintf("%s%%", n1(r$thr_per_gpu_pct_change)))
  add(sprintf("thr_per_gpu_absdiff_%s_%s", step_tag, r$band), sprintf("%s MSamples/s", n1(r$thr_per_gpu_abs_diff)))
  add(sprintf("me_pctchange_%s_%s", step_tag, r$band), sprintf("%s%%", n1(r$me_pct_change)))
  add(sprintf("me_absdiff_pp_%s_%s", step_tag, r$band), sprintf("%s pp", n1(r$me_abs_diff_pp)))
}

add("SECTION", "=== Inclinacao (slope) e ajuste linear (Parte 3) ===")
for (i in seq_len(nrow(part3_slopes))) {
  r <- part3_slopes[i, ]
  add(sprintf("slope_thr_per_gpu_%s", r$band), sprintf("%s MSamples/s por nó", n2(r$slope_throughput_per_gpu_per_node)))
  add(sprintf("r2_thr_per_gpu_%s", r$band), n3(r$r2_throughput_per_gpu_vs_nodes))
  add(sprintf("slope_me_%s", r$band), sprintf("%s pp por nó", n2(r$slope_me_pp_per_node)))
  add(sprintf("r2_me_%s", r$band), n3(r$r2_me_vs_nodes))
}

writeLines(L, out_file)
n_placeholders <- sum(str_starts(L, "<"))
cat(sprintf("Wrote %d placeholders to %s\n", n_placeholders, out_file))
