# build_sim_vs_real_timeline.R — exploratory variants of fig1 (timeline
# matrix) that add the SIMULATED trace alongside the REAL one, per
# (nodes, band) config, to visually test whether SimGrid reproduces not
# just the ME scalar but the temporal masking PATTERN.
#
# DATA SOURCES (see LEVEL2_FINDINGS.md sec 6.5/6.6 for why N differs by row):
#   nodes 1-2: REAL = g5k/results (Table 3's own N: 1344, 1728, unchanged).
#              SIM  = simgrid-chuc-validation/results/ (Level 1, same N).
#   nodes 3-4: REAL = simgrid-chuc-validation/results_reduced_n_real/
#              (genuine distributed MPI, N=1800 -- NOT Table 3's 1920/2176).
#              SIM  = simgrid-chuc-validation/results_reduced_n/ (N=1800).
#              Same N on both sides for these two rows -- that is the whole
#              point: comparable to Table 3 in SHAPE only, not in absolute N.
#
# Reuses build_load_charts.R's core geometry/theme decisions (binned
# rectangles, normalised x-axis, per-panel absolute-duration band) verbatim
# for visual continuity with the published fig1 -- only the facet layout
# (this file's actual subject) and the generalised data loader (handles
# both PMPI_-prefixed/rank-N-dashed sim traces and plain MPI_/rankN real
# traces) are new.
suppressMessages(library(tidyverse))

FIG_DIR <- "analysis/results_package/figures"
N_BINS <- 120

FILL_COLORS <- c(Compute = "#F5D547", MPI_Irecv = "#4DAF4A", MPI_Isend = "#E41A1C", MPI_Waitall = "#377EB8")
FILL_LEVELS <- c("Compute", "MPI_Irecv", "MPI_Isend", "MPI_Waitall")
COMM_STATES <- c("MPI_Irecv", "MPI_Isend", "MPI_Waitall")
BAND_LABEL <- c("1gbit" = "1 Gbit/s", "10gbit" = "10 Gbit/s", "25gbit" = "25 Gbit/s")
BAND_ORDER <- c("1gbit", "10gbit", "25gbit")
BAND_TO_SIMDIR <- c("1gbit" = "1Gbps", "10gbit" = "10Gbps", "25gbit" = "25Gbps")

# ---- generalised loader: `is_sim` strips the PMPI_ profiling prefix and
# extracts the rank index by digits-only regex (handles both sim's
# "rank-N" and real's "rankN" Container spelling). --------------------------
load_windowed_events <- function(path, is_sim) {
  df <- read_csv(path,
    col_names = c("Nature", "Container", "Type", "Start", "End", "Duration", "Imbrication", "Value"),
    col_types = cols(Nature = col_character(), Container = col_character(), Type = col_character(),
                      Start = col_double(), End = col_double(), Duration = col_double(),
                      Imbrication = col_double(), Value = col_character()),
    trim_ws = TRUE, progress = FALSE
  ) |>
    mutate(Container = str_trim(Container), Value = str_trim(Value))

  if (is_sim) df <- df |> mutate(Value = str_remove(Value, "^P(?=MPI_)"))

  window_start <- df |> filter(Value == "MPI_Irecv") |> pull(Start) |> min(na.rm = TRUE)
  window_end   <- df |> filter(Value == "MPI_Waitall") |> pull(End) |> max(na.rm = TRUE)
  window_length <- window_end - window_start

  ranks <- df |> distinct(Container) |>
    mutate(rank_num = as.integer(str_extract(Container, "\\d+"))) |>
    arrange(rank_num) |> mutate(rank_idx = row_number() - 1)

  ev <- df |>
    filter(Value %in% COMM_STATES) |>
    filter(Start < window_end, End > window_start) |>
    mutate(
      Start = pmax(Start, window_start) - window_start,
      End   = pmin(End, window_end) - window_start
    ) |>
    filter(End > Start) |>
    left_join(ranks, by = "Container") |>
    select(rank_idx, Start, End, Value)

  list(events = ev, window_length = window_length, n_ranks = nrow(ranks))
}

add_compute_gaps <- function(ev, window_length) {
  gaps <- ev |>
    group_by(rank_idx) |>
    arrange(Start, .by_group = TRUE) |>
    reframe(gap_start = c(0, End), gap_end = c(Start, window_length)) |>
    mutate(dur = gap_end - gap_start) |>
    filter(dur > 1e-9) |>
    transmute(rank_idx, Start = gap_start, End = gap_end, Value = "Compute")
  bind_rows(ev, gaps)
}

bin_events <- function(ev_full, window_length, n_bins = N_BINS) {
  bin_width <- window_length / n_bins
  ev <- ev_full |>
    mutate(
      bin_lo = pmax(0L, as.integer(floor(Start / bin_width))),
      bin_hi = pmin(n_bins - 1L, as.integer(floor((End - 1e-12) / bin_width)))
    )
  single <- ev |> filter(bin_lo == bin_hi) |>
    transmute(rank_idx, bin = bin_lo, Value, dur = End - Start)
  multi <- ev |> filter(bin_hi > bin_lo)
  multi_expanded <- if (nrow(multi) > 0) {
    multi |>
      mutate(row = row_number()) |>
      group_by(row) |>
      reframe(
        bin = bin_lo:bin_hi,
        rank_idx = rank_idx, Value = Value,
        bstart = bin * bin_width, bend = (bin + 1) * bin_width,
        dur = pmin(End, bend) - pmax(Start, bstart)
      ) |>
      filter(dur > 0) |>
      select(rank_idx, bin, Value, dur)
  } else {
    tibble(rank_idx = integer(), bin = integer(), Value = character(), dur = double())
  }
  bind_rows(single, multi_expanded) |>
    group_by(rank_idx, bin, Value) |>
    summarise(dur = sum(dur), .groups = "drop") |>
    mutate(frac = dur / bin_width)
}

to_rects <- function(binned) {
  binned |>
    mutate(Value = factor(Value, levels = FILL_LEVELS)) |>
    group_by(rank_idx, bin) |>
    arrange(Value, .by_group = TRUE) |>
    mutate(cum_hi = cumsum(frac), cum_lo = lag(cum_hi, default = 0)) |>
    ungroup() |>
    transmute(
      xmin = bin / N_BINS, xmax = (bin + 1) / N_BINS,
      ymin = rank_idx + cum_lo, ymax = rank_idx + pmin(cum_hi, 1),
      Value
    )
}

# ---- resolve one (nodes, band, source) cell to a dc.csv path + N + is_sim
ANCHORS_N <- c(`1` = 1344, `2` = 1728, `3` = 1920, `4` = 2176)  # Table 3 (real, nodes 1-2 only used)
REDUCED_N <- 1800  # nodes 3-4, both sides

thr_raw <- read_csv("analysis/throughput_raw.csv", show_col_types = FALSE)
pick_representative_rep <- function(eid) {
  d <- thr_raw |> filter(experiment_id == eid, checkpoint_status == "done")
  if (nrow(d) == 0) stop(paste("No done reps for", eid))
  med <- median(d$total_time)
  d$rep[which.min(abs(d$total_time - med))]
}

resolve_cell <- function(nodes, band, source) {
  if (source == "real") {
    if (nodes <= 2) {
      N <- ANCHORS_N[[as.character(nodes)]]
      gpus <- nodes * 4
      eid <- sprintf("bench_%s_%dn_%dg_N%d", band, nodes, gpus, N)
      rep_n <- pick_representative_rep(eid)
      path <- file.path("g5k/results", eid, paste0("rep", rep_n), "dc.csv")
      is_sim <- FALSE
    } else {
      N <- REDUCED_N
      path <- sprintf("simgrid-chuc-validation/results_reduced_n_real/%dn_%s/dc.csv", nodes, band)
      is_sim <- FALSE
    }
  } else {  # source == "sim"
    sb <- BAND_TO_SIMDIR[[band]]
    if (nodes <= 2) {
      N <- ANCHORS_N[[as.character(nodes)]]
      path <- sprintf("simgrid-chuc-validation/results/%dn_%s/dc.csv", nodes, sb)
    } else {
      N <- REDUCED_N
      path <- sprintf("simgrid-chuc-validation/results_reduced_n/%dn_%s/dc.csv", nodes, sb)
    }
    is_sim <- TRUE
  }
  list(path = path, N = N, is_sim = is_sim)
}

one_cell <- function(nodes, band, source) {
  rc <- resolve_cell(nodes, band, source)
  loaded <- load_windowed_events(rc$path, rc$is_sim)
  full_ev <- add_compute_gaps(loaded$events, loaded$window_length)
  rects <- to_rects(bin_events(full_ev, loaded$window_length))
  list(
    rects = rects |> mutate(nodes = nodes, band = band, source = source),
    meta = tibble(nodes = nodes, band = band, source = source, N = rc$N,
                  n_ranks = loaded$n_ranks, window_length = loaded$window_length)
  )
}

cat("Loading all (nodes x band x source) cells...\n")
grid_all <- expand_grid(nodes = 1:4, band = BAND_ORDER, source = c("real", "sim"))
cells_all <- pmap(grid_all, one_cell)
rects_all <- map_dfr(cells_all, "rects")
meta_all  <- map_dfr(cells_all, "meta")
cat(sprintf("Loaded %d cells.\n", nrow(meta_all)))

SOURCE_LABEL <- c(real = "Real", sim = "Simulated")

BAND_GAP <- 0.30
BAND_H   <- 1.35

tband_all <- meta_all |>
  mutate(
    ymin = n_ranks + BAND_GAP,
    ymax = n_ranks + BAND_GAP + BAND_H,
    y_text = n_ranks + BAND_GAP + BAND_H / 2,
    lab = sprintf("%.0f s", window_length)
  )

# ---- shared theme/geometry builder: takes pre-faceted-label data frames
# (caller adds whatever composite factor column(s) it wants to facet by)
# and a facet spec (a facet_grid()/facet_wrap() call), returns the ggplot.
base_plot <- function(rects_l, meta_l, tband_l, facet_spec, y_break_step = NULL) {
  ggplot(rects_l) +
    geom_rect(
      data = tband_l, inherit.aes = FALSE,
      aes(xmin = 0, xmax = 1, ymin = ymin, ymax = ymax),
      fill = "grey90", colour = NA
    ) +
    geom_text(
      data = tband_l, inherit.aes = FALSE,
      aes(x = 0.985, y = y_text, label = lab),
      hjust = 1, vjust = 0.5, size = 1.85, colour = "grey20"
    ) +
    geom_rect(aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = Value)) +
    geom_rect(
      data = meta_l, inherit.aes = FALSE,
      aes(xmin = 0, xmax = 1, ymin = 0, ymax = n_ranks),
      fill = NA, colour = "grey45", linewidth = 0.25
    ) +
    facet_spec +
    scale_fill_manual(values = FILL_COLORS, limits = FILL_LEVELS, name = NULL, drop = FALSE) +
    scale_x_continuous(breaks = c(0, 0.5, 1), labels = c("0", "50", "100"), expand = c(0, 0)) +
    scale_y_continuous(
      breaks = function(l) {
        n <- round(l[2] - BAND_GAP - BAND_H)
        step <- if (!is.null(y_break_step)) y_break_step else if (n <= 5) 1 else 4
        seq(0.5, n - 0.5, by = step)
      },
      labels = function(b) as.integer(b - 0.5),
      expand = c(0, 0)
    ) +
    labs(x = "Elapsed time [% of run duration]", y = "MPI rank") +
    guides(fill = guide_legend(nrow = 1, keywidth = unit(8, "pt"), keyheight = unit(6, "pt"))) +
    theme_bw(base_size = 8) +
    theme(
      panel.grid = element_blank(),
      panel.spacing.x = unit(10, "pt"),
      panel.spacing.y = unit(3, "pt"),
      panel.border = element_blank(),
      strip.background.x = element_rect(fill = "grey88", colour = NA),
      strip.background.y = element_blank(),
      strip.text.x = element_text(size = 6.6, colour = "grey10",
                                  margin = margin(2.2, 2.2, 2.2, 2.2)),
      strip.text.y.left = element_text(size = 6.6, angle = 0, colour = "grey15",
                                       hjust = 1, lineheight = 1.05,
                                       margin = margin(3, 4, 3, 1)),
      strip.placement = "outside",
      axis.text = element_text(size = 6.0, colour = "grey30"),
      axis.title = element_text(size = 7.2, colour = "grey15"),
      axis.title.x = element_text(margin = margin(t = 2.5)),
      axis.title.y = element_text(margin = margin(r = 2.5)),
      axis.ticks = element_line(linewidth = 0.22, colour = "grey55"),
      axis.ticks.length = unit(1.3, "pt"),
      legend.position = "bottom",
      legend.margin = margin(0, 0, 0, 0),
      legend.box.margin = margin(-5, 0, 0, 0),
      legend.text = element_text(size = 7.0, colour = "grey15"),
      plot.margin = margin(2, 3, 1, 2)
    )
}

node_lab <- function(nodes) {
  N <- ifelse(nodes <= 2, ANCHORS_N[as.character(nodes)], REDUCED_N)
  sprintf("%d node%s\nN = %d", nodes, ifelse(nodes > 1, "s", ""), N)
}
# Single-line variant for row strips rendered ROTATED 90 degrees (V5): an
# embedded \n in text rotated by theme(strip.text.y.left = angle = 90)
# would stack the two lines side by side after rotation instead of reading
# as one clean vertical run, so this joins them with ", " instead.
node_lab_oneline <- function(nodes) {
  N <- ifelse(nodes <= 2, ANCHORS_N[as.character(nodes)], REDUCED_N)
  sprintf("%d node%s, N = %d", nodes, ifelse(nodes > 1, "s", ""), N)
}

# =====================================================================
# VERSION 1 — side-by-side columns: for each of the 12 (nodes,band)
# configs, two adjacent panels (Real | Simulated). Grid stays 4 rows x
# 3 band-groups, each band-group is 2 columns wide (6 columns total).
# =====================================================================
# No ggh4x available -> emulate the nested "band group containing 2 source
# columns" header with a single composite factor column instead of true
# nested strips: "1 Gbit/s | Real", "1 Gbit/s | Simulated", "10 Gbit/s |
# Real", ... in that fixed order, so the two Real/Simulated columns for the
# same band still land visually adjacent.
mk_bandsource_levels <- function() {
  as.vector(t(outer(BAND_LABEL[BAND_ORDER], c("Real", "Simulated"), paste, sep = " | ")))
}
v1_node_levels <- node_lab(1:4)
v1_bs_levels <- mk_bandsource_levels()
mk_bs_label <- function(band, source) {
  factor(paste(BAND_LABEL[band], SOURCE_LABEL[source], sep = " | "), levels = v1_bs_levels)
}
r1 <- rects_all |> mutate(
  nodes_label = factor(node_lab(nodes), levels = v1_node_levels),
  bandsource_label = mk_bs_label(band, source)
)
m1 <- meta_all |> mutate(
  nodes_label = factor(node_lab(nodes), levels = v1_node_levels),
  bandsource_label = mk_bs_label(band, source)
)
t1 <- tband_all |> mutate(
  nodes_label = factor(node_lab(nodes), levels = v1_node_levels),
  bandsource_label = mk_bs_label(band, source)
)
p1 <- base_plot(r1, m1, t1,
  facet_spec = facet_grid(nodes_label ~ bandsource_label, scales = "free_y", space = "free_y", switch = "y")
) + theme(strip.text.x = element_text(size = 6.0))
ggsave(file.path(FIG_DIR, "fig1_sim_vs_real_v1_sidebyside.pdf"), p1, width = 11.5, height = 4.8, device = cairo_pdf)
cat("Wrote fig1_sim_vs_real_v1_sidebyside.pdf\n")

# =====================================================================
# VERSION 2 — alternating rows: for each node count, a Real row then a
# Simulated row immediately below it. Bandwidth stays in columns (3).
# 8 rows total (4 nodes x 2 sources).
# =====================================================================
v2_row_levels <- as.vector(rbind(
  paste0(node_lab(1:4), " — Real"),
  paste0(node_lab(1:4), " — Simulated")
))
mk_row_label <- function(nodes, source) {
  factor(paste0(node_lab(nodes), " — ", SOURCE_LABEL[source]), levels = v2_row_levels)
}
r2 <- rects_all |> mutate(
  row_label = mk_row_label(nodes, source),
  band_label = factor(BAND_LABEL[band], levels = BAND_LABEL[BAND_ORDER])
)
m2 <- meta_all |> mutate(
  row_label = mk_row_label(nodes, source),
  band_label = factor(BAND_LABEL[band], levels = BAND_LABEL[BAND_ORDER])
)
t2 <- tband_all |> mutate(
  row_label = mk_row_label(nodes, source),
  band_label = factor(BAND_LABEL[band], levels = BAND_LABEL[BAND_ORDER])
)
p2 <- base_plot(r2, m2, t2,
  facet_spec = facet_grid(row_label ~ band_label, scales = "free_y", space = "free_y", switch = "y")
)
ggsave(file.path(FIG_DIR, "fig1_sim_vs_real_v2_alternating_rows.pdf"), p2, width = 7.0, height = 8.6, device = cairo_pdf)
cat("Wrote fig1_sim_vs_real_v2_alternating_rows.pdf\n")

# =====================================================================
# VERSION 3 — separate compact figure, ONLY nodes 1-2 (exact-N match),
# as a fig1-replacement/companion candidate. Side-by-side real|sim per
# band (same idea as V1 but restricted so it reads as a standalone fig).
# =====================================================================
v3_node_levels <- node_lab(1:2)
r3 <- rects_all |> filter(nodes <= 2) |> mutate(
  nodes_label = factor(node_lab(nodes), levels = v3_node_levels),
  bandsource_label = mk_bs_label(band, source)
)
m3 <- meta_all |> filter(nodes <= 2) |> mutate(
  nodes_label = factor(node_lab(nodes), levels = v3_node_levels),
  bandsource_label = mk_bs_label(band, source)
)
t3 <- tband_all |> filter(nodes <= 2) |> mutate(
  nodes_label = factor(node_lab(nodes), levels = v3_node_levels),
  bandsource_label = mk_bs_label(band, source)
)
p3 <- base_plot(r3, m3, t3,
  facet_spec = facet_grid(nodes_label ~ bandsource_label, scales = "free_y", space = "free_y", switch = "y")
) + theme(strip.text.x = element_text(size = 6.2))
ggsave(file.path(FIG_DIR, "fig1_sim_vs_real_v3_nodes1to2_only.pdf"), p3, width = 8.0, height = 3.0, device = cairo_pdf)
cat("Wrote fig1_sim_vs_real_v3_nodes1to2_only.pdf\n")

# =====================================================================
# VERSION 4 — reduced, 1 Gbit/s only: real vs sim for all 4 node counts.
# Rows = node count (4), columns = source (2). Fewer panels overall.
# =====================================================================
sel4_band <- "1gbit"
v4_node_levels <- node_lab(1:4)
r4 <- rects_all |> filter(band == sel4_band) |> mutate(
  nodes_label = factor(node_lab(nodes), levels = v4_node_levels),
  source_label = factor(SOURCE_LABEL[source], levels = c("Real", "Simulated"))
)
m4 <- meta_all |> filter(band == sel4_band) |> mutate(
  nodes_label = factor(node_lab(nodes), levels = v4_node_levels),
  source_label = factor(SOURCE_LABEL[source], levels = c("Real", "Simulated"))
)
t4 <- tband_all |> filter(band == sel4_band) |> mutate(
  nodes_label = factor(node_lab(nodes), levels = v4_node_levels),
  source_label = factor(SOURCE_LABEL[source], levels = c("Real", "Simulated"))
)
p4 <- base_plot(r4, m4, t4,
  facet_spec = facet_grid(nodes_label ~ source_label, scales = "free_y", space = "free_y", switch = "y")
) +
  labs(caption = "Bandwidth: 1 Gbit/s only (largest real-vs-simulated divergence, Table 5).")
ggsave(file.path(FIG_DIR, "fig1_sim_vs_real_v4_1gbit_only.pdf"), p4, width = 5.2, height = 6.2, device = cairo_pdf)
cat("Wrote fig1_sim_vs_real_v4_1gbit_only.pdf\n")

# =====================================================================
# VERSION 5 — exact original fig1 grid (4 rows x 3 band columns, one
# panel per config, same strip headers as the published figure) but each
# panel's interior is split into two sub-timelines sharing the same y
# (rank) axis: Real on the left half, Simulated on the right half, each
# with its OWN local 0-100% x-scale (so within-run pacing stays directly
# comparable to the original single-source figure), separated by a thin
# vertical rule. This is the "same grid, split cell" layout requested
# specifically as a variant of V1 that keeps the ORIGINAL panelling
# instead of doubling the column count.
# =====================================================================
HALF_GAP <- 0.06  # blank gap between the Real and Simulated halves, in panel-x units
half_x <- function(x, source) {
  # maps a 0..1 (normalised elapsed time) value into the left half
  # ([0, 0.5-HALF_GAP/2]) for source=="real" or the right half
  # ([0.5+HALF_GAP/2, 1]) for source=="sim", each independently spanning
  # its own local 0-100%.
  half_w <- 0.5 - HALF_GAP / 2
  ifelse(source == "real", x * half_w, 0.5 + HALF_GAP / 2 + x * half_w)
}

v5_node_levels <- node_lab_oneline(1:4)
r5 <- rects_all |> mutate(
  xmin = half_x(xmin, source), xmax = half_x(xmax, source),
  nodes_label = factor(node_lab_oneline(nodes), levels = v5_node_levels),
  band_label  = factor(BAND_LABEL[band], levels = BAND_LABEL[BAND_ORDER])
)
m5 <- meta_all |> mutate(
  nodes_label = factor(node_lab_oneline(nodes), levels = v5_node_levels),
  band_label  = factor(BAND_LABEL[band], levels = BAND_LABEL[BAND_ORDER])
)
# meta_all has one row per (nodes,band,source); the panel frame/rank-count
# only needs ONE frame per (nodes,band) -- both sources share n_ranks
# within a cell by construction (same node count => same rank count).
m5_frame <- m5 |> distinct(nodes_label, band_label, n_ranks)

t5 <- tband_all |> mutate(
  x_text = half_x(0.985, source),
  hjust_text = 1,
  nodes_label = factor(node_lab_oneline(nodes), levels = v5_node_levels),
  band_label  = factor(BAND_LABEL[band], levels = BAND_LABEL[BAND_ORDER]),
  lab = sprintf("%s, %.0f s", ifelse(source == "real", "Real execution", "Simulated execution"), window_length)
)
t5_frame <- t5 |> distinct(nodes_label, band_label, ymin, ymax)

divider5 <- m5_frame |> mutate(x = 0.5)

p5 <- ggplot(r5) +
  geom_rect(
    data = t5_frame, inherit.aes = FALSE,
    aes(xmin = 0, xmax = 1, ymin = ymin, ymax = ymax),
    fill = "grey90", colour = NA
  ) +
  geom_text(
    data = t5, inherit.aes = FALSE,
    aes(x = x_text, y = (ymin + ymax) / 2, label = lab, hjust = hjust_text),
    vjust = 0.5, size = 2.1, colour = "grey20"
  ) +
  geom_rect(aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = Value)) +
  geom_rect(
    data = m5_frame, inherit.aes = FALSE,
    aes(xmin = 0, xmax = 1, ymin = 0, ymax = n_ranks),
    fill = NA, colour = "grey45", linewidth = 0.25
  ) +
  geom_vline(
    data = divider5, inherit.aes = FALSE,
    aes(xintercept = x), colour = "white", linewidth = 0.9
  ) +
  facet_grid(nodes_label ~ band_label, scales = "free_y", space = "free_y", switch = "y") +
  scale_fill_manual(values = FILL_COLORS, limits = FILL_LEVELS, name = NULL, drop = FALSE) +
  # breaks/labels appear TWICE (once per half): 0/50/100 for Real, then
  # 0/50/100 again for Simulated, each mapped through half_x().
  scale_x_continuous(
    breaks = half_x(c(0, 0.5, 1, 0, 0.5, 1), rep(c("real", "sim"), each = 3)),
    labels = rep(c("0", "50", "100"), 2),
    expand = c(0, 0)
  ) +
  scale_y_continuous(
    breaks = function(l) {
      n <- round(l[2] - BAND_GAP - BAND_H)
      step <- if (n <= 5) 1 else 4
      seq(0.5, n - 0.5, by = step)
    },
    labels = function(b) as.integer(b - 0.5),
    expand = c(0, 0)
  ) +
  labs(
    x = "Elapsed time [% of run duration] — Real (left) | Simulated (right)",
    y = "MPI rank"
  ) +
  guides(fill = guide_legend(nrow = 1, keywidth = unit(8, "pt"), keyheight = unit(6, "pt"))) +
  theme_bw(base_size = 8) +
  theme(
    panel.grid = element_blank(),
    panel.spacing.x = unit(14, "pt"),
    panel.spacing.y = unit(3, "pt"),
    panel.border = element_blank(),
    strip.background.x = element_rect(fill = "grey88", colour = NA),
    strip.background.y = element_blank(),
    strip.text.x = element_text(size = 7.4, colour = "grey10",
                                margin = margin(2.5, 2.5, 2.5, 2.5)),
    strip.text.y.left = element_text(size = 5.5, angle = 90, colour = "grey15",
                                     hjust = 0.5, vjust = 0.5, lineheight = 1.05,
                                     margin = margin(3, 4, 3, 1)),
    strip.placement = "outside",
    axis.text.x = element_text(size = 5.0, colour = "grey30"),
    axis.text.y = element_text(size = 6.2, colour = "grey30"),
    axis.title = element_text(size = 7.2, colour = "grey15"),
    axis.title.x = element_text(margin = margin(t = 2.5)),
    axis.title.y = element_text(margin = margin(r = 2.5)),
    axis.ticks = element_line(linewidth = 0.22, colour = "grey55"),
    axis.ticks.length = unit(1.3, "pt"),
    legend.position = "bottom",
    legend.margin = margin(0, 0, 0, 0),
    legend.box.margin = margin(-5, 0, 0, 0),
    legend.text = element_text(size = 7.0, colour = "grey15"),
    plot.margin = margin(2, 3, 1, 2)
  )

ggsave(file.path(FIG_DIR, "fig1_sim_vs_real_v5_split_cell.pdf"), p5, width = 9.5, height = 6.8, device = cairo_pdf)
ggsave(file.path(FIG_DIR, "fig1_sim_vs_real_v5_split_cell.png"), p5, width = 9.5, height = 6.8, dpi = 300)
cat("Wrote fig1_sim_vs_real_v5_split_cell.pdf\n")

cat("\nAll 5 versions written to ", FIG_DIR, "\n", sep = "")
