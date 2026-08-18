# Generates Figures 2-4 (PDF+PNG) for the 4-anchor x 3-band grid.
# Figure 1 is generated separately by build_load_charts.R: a single 4x3
# small-multiples matrix (node count x bandwidth) of per-rank timelines.
# (A transposed, two-figure split was tried and rejected -- see
# build_load_charts.R header for the final layout decision.) Reads only from
# tables already written by build_results_package.R plus the raw per-rep
# CSVs -- no recomputation of statistics here.
#
# 1:4 nodes here matches current data reality -- the 5-node anchor
# (N=2340, 2x2x5) exists in g5k/csv/experimentos.csv but the campaign itself
# has not run yet.
#
# LANGUAGE VARIANTS: Figures 2, 3, and 4 are each rendered twice, _pt and
# _en, identical data/layout/style, only visible text differing (axis
# titles, facet/category labels, and legend entries where they are not
# already language-neutral). Figure 3 (relative gain by band transition) is
# not currently referenced in main.tex, but is kept in sync with the other
# two anyway so it is ready the moment it is needed.
suppressMessages(library(tidyverse))

out_dir <- "analysis/results_package"
tab_dir <- file.path(out_dir, "tables")
fig_dir <- file.path(out_dir, "figures")

BAND_LABEL <- c("1gbit" = "1 Gbit/s", "10gbit" = "10 Gbit/s", "25gbit" = "25 Gbit/s")
BAND_ORDER <- c("1gbit", "10gbit", "25gbit")
BAND_COLORS <- c("1 Gbit/s" = "#D55E00", "10 Gbit/s" = "#0072B2", "25 Gbit/s" = "#009E73")

part1 <- read_csv(file.path(tab_dir, "part1_statistics.csv"), show_col_types = FALSE) |>
  mutate(band_label = factor(BAND_LABEL[band], levels = BAND_LABEL[BAND_ORDER]))

part2 <- read_csv(file.path(tab_dir, "part2_band_gains.csv"), show_col_types = FALSE)
part3_raw <- read_csv(file.path(tab_dir, "part3_scaling_raw.csv"), show_col_types = FALSE) |>
  mutate(band_label = factor(BAND_LABEL[band], levels = BAND_LABEL[BAND_ORDER]))

theme_pkg <- theme_bw(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    strip.background = element_rect(fill = "grey90", color = NA),
    legend.position = "bottom"
  )

save_fig <- function(p, name, width = 8, height = 5) {
  ggsave(file.path(fig_dir, paste0(name, ".pdf")), p, width = width, height = height, device = cairo_pdf)
  ggsave(file.path(fig_dir, paste0(name, ".png")), p, width = width, height = height, dpi = 300)
}

suppressMessages(library(patchwork))

# The former per-topology bar charts of Throughput/Masking Effectiveness, and
# the former throughput/GPU-vs-nodes line chart, were RETIRED: bar/line/scatter
# charts of already-tabulated aggregate values do not illustrate the masking
# mechanism. The masking mechanism is shown by Figure 1 (build_load_charts.R).
# The throughput/GPU-per-node values remain available in Tabela 3b/3c.

# No embedded title/subtitle anywhere below: the LaTeX \caption carries that
# text, and a plot-embedded title duplicates it redundantly in the compiled
# figure (main.tex TODO A).

LANG_TEXT_FIG2 <- list(
  pt = list(x_title = "Número de nós", y_title = "Masking Effectiveness (%)"),
  en = list(x_title = "Number of nodes", y_title = "Effective Overlap Ratio, ME (%)")
)
LANG_TEXT_FIG3 <- list(
  pt = list(x_title = "Topologia", y_title = "Ganho relativo (%)", node_fmt = "%d nó(s)"),
  en = list(x_title = "Topology", y_title = "Relative gain (%)", node_fmt = "%d node(s)")
)
LANG_TEXT_FIG4 <- list(
  pt = list(x_title = "Topologia", node_fmt = "%d nó(s)",
            y_title = "(Ganho 10→25 Gbit/s) / (Ganho 1→10 Gbit/s), em %"),
  en = list(x_title = "Topology", node_fmt = "%d node(s)",
            y_title = "(Gain 10→25 Gbit/s) / (Gain 1→10 Gbit/s), in %")
)

# --------------------------------------------------------------------
# Figure 2: Masking Effectiveness vs node count, one curve per band
# --------------------------------------------------------------------
build_fig2 <- function(lang) {
  txt <- LANG_TEXT_FIG2[[lang]]
  p <- ggplot(part3_raw, aes(x = nodes, y = 100 * mean_me, color = band_label, group = band_label)) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 2.8) +
    scale_color_manual(values = BAND_COLORS, name = NULL) +
    scale_x_continuous(breaks = 1:4) +
    coord_cartesian(ylim = c(0, 100)) +
    labs(x = txt$x_title, y = txt$y_title, title = NULL, subtitle = NULL) +
    theme_pkg
  save_fig(p, sprintf("fig2_masking_effectiveness_vs_nodes_%s", lang))
}
build_fig2("pt")
build_fig2("en")

# --------------------------------------------------------------------
# Figure 3: relative gain (%) as a function of bandwidth transition,
# faceted/grouped by topology -- throughput and ME side by side
# --------------------------------------------------------------------
gains_long_base <- part2 |>
  select(nodes, thr_gain_1to10_pct, thr_gain_10to25_pct, me_gain_1to10_pct, me_gain_10to25_pct) |>
  pivot_longer(-nodes, names_to = "key", values_to = "gain_pct") |>
  mutate(
    metric = if_else(str_starts(key, "thr_"), "Throughput", "ME"),
    transition = if_else(str_detect(key, "1to10"), "1→10 Gbit/s", "10→25 Gbit/s"),
    transition = factor(transition, levels = c("1→10 Gbit/s", "10→25 Gbit/s"))
  )

build_fig3 <- function(lang) {
  txt <- LANG_TEXT_FIG3[[lang]]
  gains_long <- gains_long_base |>
    mutate(nodes_lbl = factor(sprintf(txt$node_fmt, nodes), levels = sprintf(txt$node_fmt, 1:4)))

  p <- ggplot(gains_long, aes(x = nodes_lbl, y = gain_pct, fill = transition)) +
    geom_col(position = position_dodge(width = 0.7), width = 0.6, color = "black", linewidth = 0.3) +
    geom_hline(yintercept = 0, linewidth = 0.3) +
    facet_wrap(~metric, scales = "free_y") +
    scale_fill_manual(values = c("1→10 Gbit/s" = "#7570B3", "10→25 Gbit/s" = "#E6AB02"), name = NULL) +
    labs(x = txt$x_title, y = txt$y_title, title = NULL, subtitle = NULL) +
    theme_pkg
  save_fig(p, sprintf("fig3_relative_gain_by_band_transition_%s", lang), width = 10, height = 5)
}
build_fig3("pt")
build_fig3("en")

# --------------------------------------------------------------------
# Figure 4: diminishing returns -- (gain 10->25) / (gain 1->10), by topology
# --------------------------------------------------------------------
dr_long_base <- part2 |>
  select(nodes, thr_diminishing_returns_pct, me_diminishing_returns_pct) |>
  pivot_longer(-nodes, names_to = "metric", values_to = "ratio_pct") |>
  mutate(metric = if_else(metric == "thr_diminishing_returns_pct", "Throughput", "ME")) |>
  # 1-node bar dropped: at one node the first-transition gain is ~0, so this
  # ratio (second-transition gain / first-transition gain) explodes and is
  # not physically interpretable (main.tex Sec. 5.2 says as much in prose;
  # the bar itself never conveyed real information, just a ~-140%/-45%
  # outlier that dwarfed the 2-4 node bars). 2, 3, 4 nodes are unaffected.
  filter(nodes != 1)

# Symmetric y-axis around zero, computed from the data: the ratio can be
# negative (the second transition is a net LOSS relative to the first, not
# just a smaller gain -- see main.tex Sec. 5.2), and an asymmetric default
# range would visually understate how large that negative excursion is
# relative to the positive side. scale_y_continuous(limits = ...) is used
# (not coord_cartesian) per explicit request: it sets the actual scale
# range, not just the viewport -- harmless here since dr_ylim is always
# >= max(abs(ratio_pct)) by construction, so nothing is clipped. Computed
# post-filter (nodes 2-4 only) so the removed 1-node outlier no longer
# drives the range.
#
# UPDATE (feedback: 2-4 node bars "extremamente baixas e horriveis de
# distinguir"): the previous version floored dr_ylim at 100 to always fit
# the y=100 dashed reference line (equal gain in both transitions). With
# actual nodes 2-4 data topping out at ~8.35 (all real values are single
# digits), that floor forced a +-100 scale onto a chart whose real content
# occupies under 10% of the visible range -- the bars were not wrong, just
# visually crushed. The 100-line was explicitly optional per the prior
# review round ("pode ficar ou sair, dependendo se ainda cabe visualmente
# na escala nova") -- it doesn't fit at this data's scale, so it is now
# dropped, and the floor removed so dr_ylim reflects the real data range.
dr_ylim <- ceiling(max(abs(dr_long_base$ratio_pct), na.rm = TRUE) / 10) * 10

build_fig4 <- function(lang) {
  txt <- LANG_TEXT_FIG4[[lang]]
  dr_long <- dr_long_base |>
    mutate(nodes_lbl = factor(sprintf(txt$node_fmt, nodes), levels = sprintf(txt$node_fmt, 2:4)))

  p <- ggplot(dr_long, aes(x = nodes_lbl, y = ratio_pct, fill = metric)) +
    geom_col(position = position_dodge(width = 0.7), width = 0.6, color = "black", linewidth = 0.3) +
    geom_hline(yintercept = 0, linewidth = 0.3) +
    scale_fill_manual(values = c("Throughput" = "#1B9E77", "ME" = "#D95F02"), name = NULL) +
    scale_y_continuous(limits = c(-dr_ylim, dr_ylim)) +
    labs(x = txt$x_title, y = txt$y_title, title = NULL, subtitle = NULL) +
    theme_pkg
  save_fig(p, sprintf("fig4_diminishing_returns_%s", lang), width = 9, height = 5.5)
}
build_fig4("pt")
build_fig4("en")

cat("Figures 2-4 written to", fig_dir, "\n")
