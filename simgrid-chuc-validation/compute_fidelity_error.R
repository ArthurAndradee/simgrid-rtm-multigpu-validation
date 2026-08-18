# compute_fidelity_error.R — the number Section 4.2 of
# papers/2026_chuc_gpu_validation/main.tex defines but never reports:
#   fidelity error = 100 * (simulated - real) / real
# for throughput (MSamples/s) and effective overlap ratio (ME), per
# (nodes, bandwidth), Option C (shared-NIC chuc platform, original poti
# network calibration, native A100 kernel sampling).
#
# Inputs:
#   - simgrid-chuc-validation/results/<nodes>n_<bw>/{dc.output,dc.csv}
#     (produced by run_validation.sh; NOT touched/regenerated here)
#   - analysis/results_package/tables/part1_statistics.csv (real campaign,
#     already published in Table 3 -- read only, never recomputed)
#
# Output: simgrid-chuc-validation/fidelity_error.csv +
#         simgrid-chuc-validation/fidelity_error_table.tex (booktabs)
suppressMessages(library(tidyverse))

DIR <- "simgrid-chuc-validation"
RESULTS_DIR <- file.path(DIR, "results")

real <- read_csv(file.path("analysis/results_package/tables/part1_statistics.csv"), show_col_types = FALSE) |>
  select(nodes, band, N, real_msamples = mean_msamples, real_me = mean_me)

# --- Masking Effectiveness: same window definition as
# analysis/masking_effectiveness.R (1 - comm_ratio, window = [first
# MPI_Irecv start, last MPI_Waitall end], clipped), reimplemented minimally
# here rather than sourcing that script (it isn't written as a library --
# see results/scripts/fig_5_4.R's header for the same reasoning). ----------
read_trace_csv <- function(path) {
  read_csv(path,
    col_names = c("Nature", "Container", "Type", "Start", "End", "Duration", "Imbrication", "Value"),
    col_types = cols(.default = col_character(), Start = col_double(), End = col_double(), Duration = col_double()),
    trim_ws = TRUE, progress = FALSE
  )
}

compute_me <- function(dc_csv_path) {
  df <- tryCatch(read_trace_csv(dc_csv_path), error = function(e) NULL)
  if (is.null(df) || nrow(df) == 0) {
    return(NA_real_)
  }
  # Level 1 traces (this simulator/tracing config) log PMPI_-prefixed state
  # names (e.g. "PMPI_Irecv"), unlike the real campaign's plain "MPI_Irecv"
  # -- strip the profiling-layer prefix so both sides use the same matching
  # logic (same fix as Level 2's compute_fidelity_error_level2.R; sim_me was
  # NA for all configs here until this was applied, 2026-08-13).
  df <- df |> mutate(Container = str_trim(Container), Value = str_remove(str_trim(Value), "^P(?=MPI_)"))
  window_start <- df |> filter(Value == "MPI_Irecv") |> pull(Start) |> min(na.rm = TRUE)
  window_end <- df |> filter(Value == "MPI_Waitall") |> pull(End) |> max(na.rm = TRUE)
  if (!is.finite(window_start) || !is.finite(window_end) || window_end <= window_start) {
    return(NA_real_)
  }
  n_ranks <- n_distinct(df$Container)
  window_length <- window_end - window_start
  comm_duration <- df |>
    filter(Start < window_end, End > window_start) |>
    mutate(clipped = pmax(0, pmin(End, window_end) - pmax(Start, window_start))) |>
    pull(clipped) |>
    sum(na.rm = TRUE)
  1 - comm_duration / (window_length * n_ranks)
}

# --- Throughput: same "rank,total_time,msamples_per_s" stdout line as the
# real campaign's dc.output (parsed identically to
# analysis/gather_metrics.R::parse_output, "*" row = global aggregate). ----
read_msamples <- function(dc_output_path) {
  lines <- readLines(dc_output_path, warn = FALSE)
  header_idx <- grep("^rank,total_time,msamples_per_s", lines)
  if (length(header_idx) == 0) {
    return(NA_real_)
  }
  csv_lines <- lines[header_idx[1]:length(lines)]
  df <- read.csv(text = paste(csv_lines, collapse = "\n"), colClasses = c("rank" = "character"))
  row <- df[df$rank == "*", ]
  if (nrow(row) == 0) NA_real_ else row$msamples_per_s[1]
}

run_dirs <- list.dirs(RESULTS_DIR, recursive = FALSE)
if (length(run_dirs) == 0) {
  stop(paste("No results found under", RESULTS_DIR, "-- run run_validation.sh first."))
}

sim <- map_dfr(run_dirs, function(d) {
  label <- basename(d)
  m <- str_match(label, "^([0-9]+)n_([0-9]+)(Gbps)$")
  if (any(is.na(m))) {
    warning(paste("Skipping unrecognized directory name:", label))
    return(NULL)
  }
  nodes <- as.integer(m[2])
  band <- paste0(m[3], "gbit") # 1Gbps -> 1gbit, matching real campaign's Banda_Rede naming
  tibble(
    nodes = nodes, band = band,
    sim_msamples = read_msamples(file.path(d, "dc.output")),
    sim_me = compute_me(file.path(d, "dc.csv"))
  )
})

joined <- sim |>
  left_join(real, by = c("nodes", "band")) |>
  mutate(
    fidelity_error_throughput_pct = 100 * (sim_msamples - real_msamples) / real_msamples,
    fidelity_error_me_pct = 100 * (sim_me - real_me) / real_me
  ) |>
  arrange(nodes, factor(band, levels = c("1gbit", "10gbit", "25gbit")))

if (any(is.na(joined$real_msamples))) {
  warning("Some simulated (nodes, band) combinations have no matching real-campaign row -- check band-name mapping (expects 1gbit/10gbit/25gbit).")
}

write_csv(joined, file.path(DIR, "fidelity_error.csv"))
cat(sprintf("Wrote %d rows to %s/fidelity_error.csv\n\n", nrow(joined), DIR))
print(joined, n = Inf, width = Inf)

# --- booktabs table, same style as results/scripts/common.R::write_booktabs
tab <- joined |>
  transmute(
    Nodes = nodes,
    Band = recode(band, "1gbit" = "1 Gbit/s", "10gbit" = "10 Gbit/s", "25gbit" = "25 Gbit/s"),
    `Sim. thr. (MSamples/s)` = sprintf("%.1f", sim_msamples),
    `Real thr. (MSamples/s)` = sprintf("%.1f", real_msamples),
    `Fidelity error thr. (%)` = sprintf("%+.1f", fidelity_error_throughput_pct),
    `Sim. ME (%)` = sprintf("%.1f", sim_me * 100),
    `Real ME (%)` = sprintf("%.1f", real_me * 100),
    `Fidelity error ME (pp)` = sprintf("%+.1f", (sim_me - real_me) * 100)
  )

lines <- c(
  "\\begin{table}[htbp]",
  "  \\centering",
  "  \\caption{Fidelity error (Option C: shared-NIC chuc platform, original poti network calibration, native A100 kernel sampling) between SimGrid prediction and real measurement, per node count and bandwidth.}",
  "  \\label{tab:fidelity-error}",
  "  \\begin{tabular}{rlrrrrrr}",
  "    \\toprule",
  paste0("    ", paste(colnames(tab), collapse = " & "), " \\\\"),
  "    \\midrule"
)
for (i in seq_len(nrow(tab))) {
  lines <- c(lines, paste0("    ", paste(as.character(unlist(tab[i, ])), collapse = " & "), " \\\\"))
}
lines <- c(lines, "    \\bottomrule", "  \\end{tabular}", "\\end{table}")
writeLines(lines, file.path(DIR, "fidelity_error_table.tex"))
cat(sprintf("\nWrote %s/fidelity_error_table.tex\n", DIR))
