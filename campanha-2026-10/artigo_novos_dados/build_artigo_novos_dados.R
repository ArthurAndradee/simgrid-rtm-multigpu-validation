# Figures and tables of the SSCAD paper, rebuilt with the 2026-10 data.
#
# Same metrics, same window and the same visual style as the paper's own
# scripts (analysis/results_package/build_figures.R, build_load_charts.R,
# build_sim_vs_real_timeline.R v5, simgrid-chuc-validation/
# compute_fidelity_error_level2.R). Figures carry no embedded title, as in
# the paper; the caption text lives in campanha-2026-10/README.md.
#
# Paper item -> output here
#   Table 3  -> tabela3_strongscale.{csv,tex}       (101 partition shapes)
#   Fig. 2   -> figura2_artigo_level2_{shared,splitduplex}_*   (paper's 12
#               configurations, real | Level 2)
#               figura2_strongscale_real_vs_level2_{25,45}gbps_*
#   Fig. 3   -> figura3_strongscale_{me,vazao}_*
#   Fig. 4   -> figura4_artigo_level2_*              (real and Level 2)
#   Table 4  -> tabela4_artigo_level2.{csv,tex}
#               tabela4_strongscale_level2.csv + figura_tabela4_strongscale_*
#
# The simulated ME needs the simulated traces (dc.csv), which are not in the
# repository; it is computed once and cached in me_simulado.csv, so the
# tables and figures 3/4 rebuild from the repository alone. Figure 2 needs
# the real and simulated traces:
#   REAL_TRACES=<dir with bench_* and strongscale_* run dirs> \
#   SIM_TRACES=<dir with results_level2_paper/ and results_level2_strongscale/> \
#     Rscript campanha-2026-10/artigo_novos_dados/build_artigo_novos_dados.R
# Run from the repository root.
suppressMessages({ library(tidyverse); library(patchwork) })

OUT <- "campanha-2026-10/artigo_novos_dados"
REAL_TRACES <- Sys.getenv("REAL_TRACES", "g5k/results")
SIM_TRACES <- Sys.getenv("SIM_TRACES", "simgrid-chuc-validation")
N_BINS <- 120

BAND_ORDER <- c("1gbit", "10gbit", "25gbit")
BAND_LABEL <- c("1gbit" = "1 Gbit/s", "10gbit" = "10 Gbit/s", "25gbit" = "25 Gbit/s")
BAND_SIMDIR <- c("1gbit" = "1Gbps", "10gbit" = "10Gbps", "25gbit" = "25Gbps")
POLICIES <- c(SHARED = "poti_cornebize_SHARED", SPLITDUPLEX = "poti_cornebize_SPLITDUPLEX")
SS_PLATFORMS <- c("25Gbps" = "poti_cornebize_25Gbps", "45Gbps" = "poti_cornebize_45Gbps")
NP_ROWS_TIMELINE <- c(4, 8, 12, 16, 20, 24)

FILL_COLORS <- c(Compute = "#F5D547", MPI_Irecv = "#4DAF4A", MPI_Isend = "#E41A1C", MPI_Waitall = "#377EB8")
FILL_LEVELS <- names(FILL_COLORS)
COMM_STATES <- c("MPI_Irecv", "MPI_Isend", "MPI_Waitall")
SERIES3 <- c("#2a78d6", "#eb6834", "#1baf7a")
NP_RAMP <- c("#86b6ef", "#6da7ec", "#3987e5", "#2a78d6", "#256abf", "#1c5cab", "#184f95", "#0d366b")

TXT <- list(
  pt = list(dec = ",", real = "Real", sim = "Simulado", nodes = "%d nó%s", nodes_s = "s",
            np_nodes = "np = %d\n%d nó%s", best = "Melhor forma", median = "Forma mediana", worst = "Pior forma",
            x_split = "Tempo decorrido [% da janela do laço] — Real (esq.) | Simulado (dir.)",
            rank = "Rank MPI", x_np = "Número de processos, np (nós)",
            me = "Masking Effectiveness, ME (%)", thr = "Vazão (MSamples/s)",
            shape_pt = "Forma de partição (média ± IC 95%)", shape_med = "Mediana das formas",
            topo = "Topologia", dr = "(Ganho 10→25 Gbit/s) / (Ganho 1→10 Gbit/s), em %",
            thr_metric = "Vazão", real_src = "Real (artigo)",
            sim_thr = "Vazão simulada (MSamples/s)", real_thr = "Vazão real (MSamples/s)",
            sim_me = "ME simulado (%)", real_me = "ME real (%)", plat = "Plataforma Level 2: %s"),
  en = list(dec = ".", real = "Real", sim = "Simulated", nodes = "%d node%s", nodes_s = "s",
            np_nodes = "np = %d\n%d node%s", best = "Best shape", median = "Median shape", worst = "Worst shape",
            x_split = "Elapsed time [% of time-loop window] — Real (left) | Simulated (right)",
            rank = "MPI rank", x_np = "Number of processes, np (nodes)",
            me = "Effective Overlap Ratio, ME (%)", thr = "Throughput (MSamples/s)",
            shape_pt = "Partition shape (mean ± 95% CI)", shape_med = "Median over shapes",
            topo = "Topology", dr = "(Gain 10→25 Gbit/s) / (Gain 1→10 Gbit/s), in %",
            thr_metric = "Throughput", real_src = "Real (paper)",
            sim_thr = "Simulated throughput (MSamples/s)", real_thr = "Real throughput (MSamples/s)",
            sim_me = "Simulated ME (%)", real_me = "Real ME (%)", plat = "Level 2 platform: %s")
)
plural <- function(n, s) ifelse(n > 1, s, "")
nodes_of <- function(np) pmax(1, ceiling(np / 4))
fmt <- function(x, d, dec) formatC(x, format = "f", digits = d, decimal.mark = dec)

theme_pkg <- theme_bw(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        strip.background = element_rect(fill = "grey90", color = NA),
        legend.position = "bottom")
save_fig <- function(p, name, width, height) {
  ggsave(file.path(OUT, paste0(name, ".pdf")), p, width = width, height = height, device = cairo_pdf)
  ggsave(file.path(OUT, paste0(name, ".png")), p, width = width, height = height, dpi = 300)
  cat("Wrote", name, "\n")
}

# ---- traces --------------------------------------------------------------
read_trace <- function(path) {
  read_csv(path,
    col_names = c("Nature", "Container", "Type", "Start", "End", "Duration", "Imbrication", "Value"),
    col_types = cols(Nature = col_character(), Container = col_character(), Type = col_character(),
                     Start = col_double(), End = col_double(), Duration = col_double(),
                     Imbrication = col_double(), Value = col_character()),
    trim_ws = TRUE, progress = FALSE) |>
    mutate(Container = str_trim(Container), Value = str_remove(str_trim(Value), "^P(?=MPI_)"))
}
trace_window <- function(df) {
  c(min(df$Start[df$Value == "MPI_Irecv"]), max(df$End[df$Value == "MPI_Waitall"]))
}
# ME exactly as analysis/masking_effectiveness.R / compute_fidelity_error_level2.R
trace_me <- function(df) {
  w <- suppressWarnings(trace_window(df))
  if (!all(is.finite(w)) || w[2] <= w[1]) return(c(me = NA_real_, window_s = NA_real_))
  L <- w[2] - w[1]
  comm <- df |> filter(Start < w[2], End > w[1]) |>
    mutate(d = pmax(0, pmin(End, w[2]) - pmax(Start, w[1]))) |> pull(d) |> sum()
  c(me = 1 - comm / (L * n_distinct(df$Container)), window_s = L)
}
global_line <- function(path) {
  l <- grep("^\\*,", readLines(path, warn = FALSE), value = TRUE)
  if (length(l) == 0) return(c(time = NA_real_, thr = NA_real_))
  v <- as.numeric(strsplit(l[1], ",")[[1]][2:3]); c(time = v[1], thr = v[2])
}

# ---- binned timeline geometry (build_load_charts.R) ----------------------
add_compute_gaps <- function(ev, L) {
  gaps <- ev |> group_by(rank_idx) |> arrange(Start, .by_group = TRUE) |>
    reframe(gap_start = c(0, End), gap_end = c(Start, L)) |>
    filter(gap_end - gap_start > 1e-9) |>
    transmute(rank_idx, Start = gap_start, End = gap_end, Value = "Compute")
  bind_rows(ev, gaps)
}
bin_events <- function(ev, L) {
  bw <- L / N_BINS
  ev <- ev |> mutate(bin_lo = pmax(0L, as.integer(floor(Start / bw))),
                     bin_hi = pmin(N_BINS - 1L, as.integer(floor((End - 1e-12) / bw))))
  single <- ev |> filter(bin_lo == bin_hi) |> transmute(rank_idx, bin = bin_lo, Value, dur = End - Start)
  multi <- ev |> filter(bin_hi > bin_lo)
  multi_x <- if (nrow(multi) > 0) {
    multi |> mutate(row = row_number()) |> group_by(row) |>
      reframe(bin = bin_lo:bin_hi, rank_idx = rank_idx, Value = Value,
              dur = pmin(End, (bin + 1) * bw) - pmax(Start, bin * bw)) |>
      filter(dur > 0) |> select(rank_idx, bin, Value, dur)
  } else tibble(rank_idx = integer(), bin = integer(), Value = character(), dur = double())
  bind_rows(single, multi_x) |> group_by(rank_idx, bin, Value) |>
    summarise(dur = sum(dur), .groups = "drop") |> mutate(frac = dur / bw)
}
to_rects <- function(b) {
  b |> mutate(Value = factor(Value, levels = FILL_LEVELS)) |>
    group_by(rank_idx, bin) |> arrange(Value, .by_group = TRUE) |>
    mutate(hi = cumsum(frac), lo = lag(hi, default = 0)) |> ungroup() |>
    transmute(xmin = bin / N_BINS, xmax = (bin + 1) / N_BINS,
              ymin = rank_idx + lo, ymax = rank_idx + pmin(hi, 1), Value)
}
cell_from_trace <- function(path) {
  df <- read_trace(path)
  w <- trace_window(df); L <- w[2] - w[1]
  ranks <- df |> distinct(Container) |>
    mutate(rank_num = as.integer(str_extract(Container, "\\d+"))) |>
    arrange(rank_num) |> mutate(rank_idx = row_number() - 1)
  ev <- df |> filter(Value %in% COMM_STATES, Start < w[2], End > w[1]) |>
    mutate(Start = pmax(Start, w[1]) - w[1], End = pmin(End, w[2]) - w[1]) |>
    filter(End > Start) |> left_join(ranks, by = "Container") |> select(rank_idx, Start, End, Value)
  list(rects = to_rects(bin_events(add_compute_gaps(ev, L), L)), n_ranks = nrow(ranks), window_s = L)
}

# ---- inputs from the repository ------------------------------------------
topo <- read_csv("analysis/strongscale_por_topologia.csv", show_col_types = FALSE)
per_rep <- read_csv("analysis/strongscale_por_rep.csv", show_col_types = FALSE)
part1 <- read_csv("analysis/results_package/tables/part1_statistics.csv", show_col_types = FALSE)
thr_raw <- read_csv("analysis/throughput_raw.csv", show_col_types = FALSE)

sim_index <- bind_rows(
  expand_grid(plataforma = names(POLICIES), nodes = 1:4, band = BAND_ORDER) |>
    mutate(conjunto = "artigo", config = sprintf("%dn_%s", nodes, BAND_SIMDIR[band]),
           subdir = file.path("results_level2_paper", unname(POLICIES[plataforma]), config)),
  expand_grid(plataforma = names(SS_PLATFORMS), config = topo$experiment_id) |>
    mutate(conjunto = "strongscale",
           subdir = file.path("results_level2_strongscale", unname(SS_PLATFORMS[plataforma]), config))
) |> select(conjunto, plataforma, config, subdir, nodes, band)

# simulated throughput: dc.output (in the repository)
sim_thr <- sim_index |> rowwise() |>
  mutate(g = list(global_line(file.path("simgrid-chuc-validation", subdir, "dc.output"))),
         sim_time_s = g[["time"]], sim_thr = g[["thr"]]) |> ungroup() |> select(-g)

# simulated ME: traces, cached
me_cache <- file.path(OUT, "me_simulado.csv")
cached <- if (file.exists(me_cache)) read_csv(me_cache, show_col_types = FALSE) else
  tibble(conjunto = character(), plataforma = character(), config = character(), sim_me = double(), sim_window_s = double())
todo <- sim_index |> anti_join(cached, by = c("conjunto", "plataforma", "config"))
if (nrow(todo) > 0) {
  cat(sprintf("Computing simulated ME for %d runs from %s ...\n", nrow(todo), SIM_TRACES))
  new <- map_dfr(seq_len(nrow(todo)), function(i) {
    p <- file.path(SIM_TRACES, todo$subdir[i], "dc.csv")
    if (!file.exists(p)) stop("missing simulated trace ", p, " (set SIM_TRACES)")
    m <- trace_me(read_trace(p))
    if (i %% 25 == 0) cat("  ", i, "/", nrow(todo), "\n")
    tibble(conjunto = todo$conjunto[i], plataforma = todo$plataforma[i], config = todo$config[i],
           sim_me = m[["me"]], sim_window_s = m[["window_s"]])
  })
  cached <- bind_rows(cached, new)
  write_csv(cached, me_cache)
}
sim <- sim_thr |> left_join(cached, by = c("conjunto", "plataforma", "config"))

# ---- Table 3: strong scaling ---------------------------------------------
tab3 <- topo |> transmute(np, nos = nodes_of(np), particao = dims, bloco_local = local_xyz, reps,
                          vazao_msamples_s = throughput_mean, vazao_ic95 = throughput_ci95,
                          me_pct = 100 * me_mean, me_ic95_pp = 100 * me_ci95)
write_csv(tab3, file.path(OUT, "tabela3_strongscale.csv"))
pm <- function(m, c, d = 1) ifelse(is.na(m), "--", sprintf(paste0("%.", d, "f $\\pm$ %.", d, "f"), m, c))
tex3 <- c("\\begin{longtable}{rrlrrr}",
  "\\caption{Throughput (MSamples/s) and effective overlap ratio ME (\\%) per partition shape, mean $\\pm$ 95\\% CI over 5 repetitions, $N = 968$, native network.}\\label{tab:strongscale}\\\\",
  "\\toprule", "np & Nodes & Partitioning & Local block & Throughput (MSamples/s) & ME (\\%) \\\\", "\\midrule", "\\endhead",
  with(tab3, sprintf("%d & %d & \\texttt{%s} & %s & %s & %s \\\\", np, nos, particao, gsub("x", "$\\\\times$", bloco_local),
                     pm(vazao_msamples_s, vazao_ic95), pm(me_pct, me_ic95_pp))),
  "\\bottomrule", "\\end{longtable}")
writeLines(tex3, file.path(OUT, "tabela3_strongscale.tex"))

# ---- Table 4: paper configurations, Level 2 SHARED / SPLITDUPLEX ---------
loops <- map_dfr(names(POLICIES), function(pol)
  read_csv(file.path("simgrid-chuc-validation/results_level2_paper", POLICIES[[pol]], "comparison_vs_real.csv"),
           show_col_types = FALSE) |>
    transmute(plataforma = pol, nodes, band = names(BAND_SIMDIR)[match(band, BAND_SIMDIR)],
              real_loop_s, sim_loop_s))
tab4a <- part1 |> select(nodes, band, N, real_thr = mean_msamples, real_me = mean_me) |>
  inner_join(sim |> filter(conjunto == "artigo") |> select(plataforma, nodes, band, sim_thr, sim_me, sim_time_s),
             by = c("nodes", "band")) |>
  left_join(loops, by = c("plataforma", "nodes", "band")) |>
  mutate(err_thr_pct = 100 * (sim_thr - real_thr) / real_thr, err_me_pp = 100 * (sim_me - real_me),
         band = factor(band, levels = BAND_ORDER)) |>
  arrange(plataforma, nodes, band) |>
  select(plataforma, nodes, band, N, real_thr, sim_thr, err_thr_pct, real_me, sim_me, err_me_pp, real_loop_s, sim_loop_s)
write_csv(tab4a, file.path(OUT, "tabela4_artigo_level2.csv"))
w4 <- tab4a |> select(nodes, band, N, real_thr, real_me, plataforma, sim_thr, err_thr_pct, sim_me, err_me_pp) |>
  pivot_wider(names_from = plataforma, values_from = c(sim_thr, err_thr_pct, sim_me, err_me_pp)) |>
  arrange(nodes, band)
sg <- function(x) sprintf("%+.1f", x)
tex4 <- c("\\begin{table}[htbp]", "\\centering\\small",
  "\\caption{Fidelity error (simulated vs.\\ real), Level 2 with two NIC sharing policies of the platform. Real values as in Table 3. Throughput error is relative; ME error is in percentage points.}",
  "\\label{tab:fidelity-level2}",
  "\\begin{tabular}{rlrrr rrrr rrrr}", "\\toprule",
  " & & & & & \\multicolumn{4}{c}{Level 2, SHARED} & \\multicolumn{4}{c}{Level 2, SPLITDUPLEX} \\\\",
  "\\cmidrule(lr){6-9}\\cmidrule(lr){10-13}",
  "Nodes & Band & $N$ & Real thr. & Real ME & Sim. thr. & Err. (\\%) & Sim. ME & Err. (pp) & Sim. thr. & Err. (\\%) & Sim. ME & Err. (pp) \\\\",
  "\\midrule",
  with(w4, sprintf("%d & %s & %d & %.1f & %.1f & %.1f & %s & %.1f & %s & %.1f & %s & %.1f & %s \\\\",
    nodes, BAND_LABEL[as.character(band)], N, real_thr, 100 * real_me,
    sim_thr_SHARED, sg(err_thr_pct_SHARED), 100 * sim_me_SHARED, sg(err_me_pp_SHARED),
    sim_thr_SPLITDUPLEX, sg(err_thr_pct_SPLITDUPLEX), 100 * sim_me_SPLITDUPLEX, sg(err_me_pp_SPLITDUPLEX))),
  "\\bottomrule", "\\end{tabular}", "\\end{table}")
writeLines(tex4, file.path(OUT, "tabela4_artigo_level2.tex"))

# ---- Table 4: strong scaling, Level 2 at 25 and 45 Gbit/s ----------------
tab4b <- topo |> select(config = experiment_id, np, dims, real_thr = throughput_mean, real_me = me_mean) |>
  inner_join(sim |> filter(conjunto == "strongscale") |> select(plataforma, config, sim_thr, sim_me), by = "config") |>
  mutate(err_thr_pct = 100 * (sim_thr - real_thr) / real_thr, err_me_pp = 100 * (sim_me - real_me)) |>
  arrange(plataforma, np) |>
  select(plataforma, experiment_id = config, np, dims, real_thr, sim_thr, err_thr_pct, real_me, sim_me, err_me_pp)
write_csv(tab4b, file.path(OUT, "tabela4_strongscale_level2.csv"))

for (lang in c("pt", "en")) {
  t <- TXT[[lang]]
  np_lab <- function(np) sprintf("%d\n(%d)", np, nodes_of(np))
  np_levels <- np_lab(sort(unique(topo$np)))

  # ---- Fig. 3: ME and throughput vs np, every shape -----------------------
  d3 <- topo |> mutate(x = factor(np_lab(np), levels = np_levels))
  med <- d3 |> group_by(x) |> summarise(me = median(me_mean, na.rm = TRUE), thr = median(throughput_mean), .groups = "drop")
  fig3 <- function(yvar, cvar, medvar, ylab, ylim = NULL, scale = 1) {
    p <- ggplot(d3, aes(x = x)) +
      geom_pointrange(aes(y = scale * .data[[yvar]], ymin = scale * (.data[[yvar]] - .data[[cvar]]),
                          ymax = scale * (.data[[yvar]] + .data[[cvar]]), colour = t$shape_pt),
                      position = position_jitter(width = 0.18, height = 0, seed = 1),
                      size = 0.35, linewidth = 0.35, na.rm = TRUE) +
      geom_line(data = med, aes(y = scale * .data[[medvar]], group = 1, colour = t$shape_med), linewidth = 0.9, na.rm = TRUE) +
      geom_point(data = med, aes(y = scale * .data[[medvar]], colour = t$shape_med), size = 2.4, na.rm = TRUE) +
      scale_colour_manual(values = setNames(c("#86b6ef", "#0d366b"), c(t$shape_pt, t$shape_med)), name = NULL) +
      labs(x = t$x_np, y = ylab) + theme_pkg
    if (!is.null(ylim)) p <- p + coord_cartesian(ylim = ylim) else p <- p + expand_limits(y = 0)
    p
  }
  save_fig(fig3("me_mean", "me_ci95", "me", t$me, c(0, 100), 100), sprintf("figura3_strongscale_me_%s", lang), 8, 5)
  save_fig(fig3("throughput_mean", "throughput_ci95", "thr", t$thr), sprintf("figura3_strongscale_vazao_%s", lang), 8, 5)

  # ---- Fig. 4: (gain 10->25)/(gain 1->10), real and Level 2 -------------
  src_levels <- c(t$real_src, "Level 2 SHARED", "Level 2 SPLITDUPLEX")
  g4 <- bind_rows(
    tab4a |> distinct(nodes, band, real_thr, real_me) |> transmute(src = t$real_src, nodes, band, thr = real_thr, me = real_me),
    tab4a |> transmute(src = paste("Level 2", plataforma), nodes, band, thr = sim_thr, me = sim_me)) |>
    pivot_longer(c(thr, me), names_to = "metric") |>
    pivot_wider(names_from = band, values_from = value) |>
    mutate(g1 = 100 * (`10gbit` - `1gbit`) / `1gbit`, g2 = 100 * (`25gbit` - `10gbit`) / `10gbit`,
           ratio = 100 * g2 / g1) |>
    filter(nodes > 1) |>
    mutate(src = factor(src, levels = src_levels),
           metric = factor(ifelse(metric == "thr", t$thr_metric, "ME"), levels = c(t$thr_metric, "ME")),
           nodes_lbl = factor(sprintf(t$nodes, nodes, plural(nodes, t$nodes_s)),
                              levels = sprintf(t$nodes, 2:4, t$nodes_s)))
  write_csv(g4 |> select(src, metric, nodes, gain_1to10_pct = g1, gain_10to25_pct = g2, ratio_pct = ratio),
            file.path(OUT, sprintf("figura4_artigo_level2_dados_%s.csv", lang)))
  p4 <- ggplot(g4, aes(x = nodes_lbl, y = ratio, fill = src)) +
    geom_col(position = position_dodge(width = 0.75), width = 0.7, colour = "black", linewidth = 0.3) +
    geom_hline(yintercept = 0, linewidth = 0.3) +
    facet_wrap(~metric, scales = "free_y") +
    scale_fill_manual(values = setNames(SERIES3, src_levels), name = NULL) +
    labs(x = t$topo, y = t$dr) + theme_pkg
  save_fig(p4, sprintf("figura4_artigo_level2_%s", lang), 9, 5.5)

  # ---- Table 4 (strong scaling) as a figure: sim vs real -----------------
  d4 <- tab4b |> mutate(np_f = factor(np, levels = sort(unique(np))),
                        plat = factor(sprintf(t$plat, sub("Gbps", " Gbit/s", plataforma))))
  np_cols <- setNames(NP_RAMP[seq_along(levels(d4$np_f))], levels(d4$np_f))
  pa <- ggplot(d4, aes(real_thr, sim_thr, colour = np_f)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey40") +
    geom_point(size = 1.6, shape = 21, stroke = 0.7) +
    scale_x_log10(labels = scales::label_number(big.mark = ifelse(lang == "pt", ".", ","), decimal.mark = t$dec)) +
    scale_y_log10(labels = scales::label_number(big.mark = ifelse(lang == "pt", ".", ","), decimal.mark = t$dec)) +
    facet_wrap(~plat, nrow = 1) + scale_colour_manual(values = np_cols, limits = names(np_cols), name = "np", drop = FALSE) +
    labs(x = t$real_thr, y = t$sim_thr) + theme_pkg
  pb <- ggplot(d4 |> filter(!is.na(sim_me)), aes(100 * real_me, 100 * sim_me, colour = np_f)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey40") +
    geom_point(size = 1.6, shape = 21, stroke = 0.7) +
    coord_equal(xlim = c(0, 100), ylim = c(0, 100)) +
    facet_wrap(~plat, nrow = 1) + scale_colour_manual(values = np_cols, limits = names(np_cols), name = "np", drop = FALSE) +
    labs(x = t$real_me, y = t$sim_me) + theme_pkg + guides(colour = "none")
  save_fig(pa / pb + plot_layout(guides = "collect") & theme(legend.position = "bottom"),
           sprintf("figura_tabela4_strongscale_%s", lang), 9, 9)
}

# ---- Fig. 2: real | simulated split-cell timelines ----------------------
BAND_GAP <- 0.30; BAND_H <- 1.35; HALF_GAP <- 0.06
half_x <- function(x, source) {
  hw <- 0.5 - HALF_GAP / 2
  ifelse(source == "real", x * hw, 0.5 + HALF_GAP / 2 + x * hw)
}
plot_split <- function(cells, row_levels, col_levels, t, time_digits, name, width, height) {
  rects <- map_dfr(cells, function(c) c$rects |> mutate(row = c$row, col = c$col, source = c$source))
  meta <- map_dfr(cells, function(c) tibble(row = c$row, col = c$col, source = c$source,
                                             n_ranks = c$n_ranks, window_s = c$window_s, dims = c$dims))
  fac <- function(d) d |> mutate(row = factor(row, levels = row_levels), col = factor(col, levels = col_levels))
  r <- rects |> mutate(xmin = half_x(xmin, source), xmax = half_x(xmax, source)) |> fac()
  frame <- meta |> distinct(row, col, n_ranks) |> fac()
  band <- frame |> mutate(ymin = n_ranks + BAND_GAP, ymax = n_ranks + BAND_GAP + BAND_H)
  lab <- meta |> fac() |> mutate(x = half_x(0.985, source), y = n_ranks + BAND_GAP + BAND_H / 2,
                                 lab = paste0(ifelse(source == "real", t$real, t$sim), ", ",
                                              fmt(window_s, time_digits, t$dec), " s"))
  dims_lab <- meta |> filter(source == "real", !is.na(dims)) |> fac() |>
    mutate(y = n_ranks + BAND_GAP + BAND_H / 2)
  p <- ggplot(r) +
    geom_rect(data = band, inherit.aes = FALSE, aes(xmin = 0, xmax = 1, ymin = ymin, ymax = ymax), fill = "grey90", colour = NA) +
    geom_text(data = lab, inherit.aes = FALSE, aes(x = x, y = y, label = lab), hjust = 1, vjust = 0.5, size = 2.0, colour = "grey20") +
    geom_text(data = dims_lab, inherit.aes = FALSE, aes(x = 0.012, y = y, label = dims), hjust = 0, vjust = 0.5,
              size = 2.0, colour = "grey10", fontface = "bold") +
    geom_rect(aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = Value)) +
    geom_rect(data = frame, inherit.aes = FALSE, aes(xmin = 0, xmax = 1, ymin = 0, ymax = n_ranks),
              fill = NA, colour = "grey45", linewidth = 0.25) +
    geom_vline(data = frame, inherit.aes = FALSE, aes(xintercept = 0.5), colour = "white", linewidth = 0.9) +
    facet_grid(row ~ col, scales = "free_y", space = "free_y", switch = "y") +
    scale_fill_manual(values = FILL_COLORS, limits = FILL_LEVELS, name = NULL, drop = FALSE) +
    scale_x_continuous(breaks = half_x(c(0, 0.5, 1, 0, 0.5, 1), rep(c("real", "sim"), each = 3)),
                       labels = rep(c("0", "50", "100"), 2), expand = c(0, 0)) +
    scale_y_continuous(breaks = function(l) { n <- round(l[2] - BAND_GAP - BAND_H); seq(0.5, n - 0.5, by = if (n <= 5) 1 else 4) },
                       labels = function(b) as.integer(b - 0.5), expand = c(0, 0)) +
    labs(x = t$x_split, y = t$rank) +
    guides(fill = guide_legend(nrow = 1, keywidth = unit(8, "pt"), keyheight = unit(6, "pt"))) +
    theme_bw(base_size = 8) +
    theme(panel.grid = element_blank(), panel.spacing.x = unit(14, "pt"), panel.spacing.y = unit(3, "pt"),
          panel.border = element_blank(),
          strip.background.x = element_rect(fill = "grey88", colour = NA), strip.background.y = element_blank(),
          strip.text.x = element_text(size = 7.4, colour = "grey10", margin = margin(2.5, 2.5, 2.5, 2.5)),
          strip.text.y.left = element_text(size = 6.8, angle = 0, colour = "grey15", hjust = 1, lineheight = 1.05,
                                           margin = margin(3, 4, 3, 1)),
          strip.placement = "outside",
          axis.text.x = element_text(size = 5.0, colour = "grey30"), axis.text.y = element_text(size = 6.2, colour = "grey30"),
          axis.title = element_text(size = 7.2, colour = "grey15"),
          axis.ticks = element_line(linewidth = 0.22, colour = "grey55"), axis.ticks.length = unit(1.3, "pt"),
          legend.position = "bottom", legend.margin = margin(0, 0, 0, 0), legend.box.margin = margin(-5, 0, 0, 0),
          legend.text = element_text(size = 7.0, colour = "grey15"), plot.margin = margin(2, 9, 1, 2))
  ggsave(file.path(OUT, paste0(name, ".pdf")), p, width = width, height = height, device = cairo_pdf)
  ggsave(file.path(OUT, paste0(name, ".png")), p, width = width, height = height, dpi = 300)
  cat("Wrote", name, "\n")
}

have_traces <- length(Sys.glob(file.path(REAL_TRACES, "bench_*", "rep*", "dc.csv"))) > 0 &&
  length(Sys.glob(file.path(SIM_TRACES, "results_level2_paper", "*", "*", "dc.csv"))) > 0
if (!have_traces) {
  cat("Traces not found (REAL_TRACES/SIM_TRACES): skipping Figure 2.\n")
} else {
  pick_rep <- function(d, time_col) { m <- median(d[[time_col]]); d$rep[which.min(abs(d[[time_col]] - m))] }

  # paper configurations: real at the Table 3 anchor sizes | Level 2
  anchor <- part1 |> distinct(nodes, N)
  real_art <- map(seq_len(nrow(anchor) * 3), function(k) {
    i <- (k - 1) %/% 3 + 1; b <- BAND_ORDER[(k - 1) %% 3 + 1]
    eid <- sprintf("bench_%s_%dn_%dg_N%d", b, anchor$nodes[i], 4 * anchor$nodes[i], anchor$N[i])
    rep_n <- pick_rep(thr_raw |> filter(experiment_id == eid, checkpoint_status == "done"), "total_time")
    c(cell_from_trace(file.path(REAL_TRACES, eid, paste0("rep", rep_n), "dc.csv")),
      list(nodes = anchor$nodes[i], N = anchor$N[i], band = b, source = "real", dims = NA_character_))
  })
  for (pol in names(POLICIES)) {
    sim_art <- map(real_art, function(rc) {
      p <- file.path(SIM_TRACES, "results_level2_paper", POLICIES[[pol]], sprintf("%dn_%s", rc$nodes, BAND_SIMDIR[[rc$band]]), "dc.csv")
      c(cell_from_trace(p), list(nodes = rc$nodes, N = rc$N, band = rc$band, source = "sim", dims = NA_character_))
    })
    for (lang in c("pt", "en")) {
      t <- TXT[[lang]]
      lab_row <- function(n, N) sprintf(paste0(t$nodes, "\nN = %d"), n, plural(n, t$nodes_s), N)
      cells <- map(c(real_art, sim_art), function(c) c(c, list(row = lab_row(c$nodes, c$N), col = BAND_LABEL[[c$band]])))
      plot_split(cells, lab_row(anchor$nodes, anchor$N), unname(BAND_LABEL[BAND_ORDER]),
                 modifyList(t, list(sim = paste(t$sim, "L2", pol))), 0,
                 sprintf("figura2_artigo_level2_%s_%s", tolower(pol), lang), 9.5, 6.8)
    }
  }

  # strong scaling: best / median / worst shape per np, real | Level 2
  choices <- topo |> filter(np %in% NP_ROWS_TIMELINE) |> group_by(np) |>
    summarise(best = experiment_id[which.max(throughput_mean)],
              median = experiment_id[which.min(abs(throughput_mean - median(throughput_mean)))],
              worst = experiment_id[which.min(throughput_mean)], .groups = "drop") |>
    pivot_longer(c(best, median, worst), names_to = "choice", values_to = "experiment_id") |>
    left_join(topo |> select(experiment_id, dims), by = "experiment_id")
  write_csv(choices, file.path(OUT, "figura2_strongscale_paineis.csv"))
  real_ss <- map(seq_len(nrow(choices)), function(i) {
    eid <- choices$experiment_id[i]
    rep_n <- pick_rep(per_rep |> filter(experiment_id == eid), "total_time_s")
    c(cell_from_trace(file.path(REAL_TRACES, eid, paste0("rep", rep_n), "dc.csv")),
      list(np = choices$np[i], choice = choices$choice[i], dims = choices$dims[i], eid = eid, source = "real"))
  })
  for (plat in names(SS_PLATFORMS)) {
    sim_ss <- map(real_ss, function(rc) {
      p <- file.path(SIM_TRACES, "results_level2_strongscale", SS_PLATFORMS[[plat]], rc$eid, "dc.csv")
      c(cell_from_trace(p), list(np = rc$np, choice = rc$choice, dims = rc$dims, eid = rc$eid, source = "sim"))
    })
    for (lang in c("pt", "en")) {
      t <- TXT[[lang]]
      lab_row <- function(np) sprintf(t$np_nodes, np, nodes_of(np), plural(nodes_of(np), t$nodes_s))
      col_lab <- c(best = t$best, median = t$median, worst = t$worst)
      cells <- map(c(real_ss, sim_ss), function(c) c(c, list(row = lab_row(c$np), col = col_lab[[c$choice]])))
      plot_split(cells, lab_row(NP_ROWS_TIMELINE), unname(col_lab),
                 modifyList(t, list(sim = paste(t$sim, "L2", sub("Gbps", " Gbit/s", plat)))), 1,
                 sprintf("figura2_strongscale_real_vs_level2_%s_%s", tolower(plat), lang), 9.5, 9.3)
    }
  }
}
cat("Done:", OUT, "\n")
