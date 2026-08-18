# Compact "small multiples" version of the Gantt/timeline figure: ONE figure
# (4 topologies x 3 bandwidths), one horizontal band per rank, time on x,
# colour = what that rank was doing. Keeps the visual language of Spadotto's
# thesis (thesis/assets/sim_gpu_10Gbps/load_256.pdf).
#
# LAYOUT (final, chosen after comparing alternatives): ROWS = node count,
# COLUMNS = bandwidth (1/10/25 Gbit/s) -- the original orientation. A
# transposed variant (bandwidth as rows, node count as columns, split into two
# figures) was tried and rejected in favour of this single unified matrix.
#
# TIME ANNOTATION (final, chosen after comparing two variants): each panel
# gets its own thin grey band ABOVE the panel frame, in the same colour/type
# family as the row/column strips, with the run's absolute duration
# (e.g. "68 s") right-aligned inside it. To place the band above the frame
# rather than over the data, the panel frame is drawn explicitly as a
# geom_rect around the data region and theme panel.border is disabled; the
# band then occupies reserved y-space outside that frame. Because
# facet_grid(space = "free_y") makes panel height proportional to the
# y-range, and rows are node count here (so every panel in a row shares the
# same rank count), the band renders at identical physical thickness in all
# twelve panels -- this property specifically requires rows = node count;
# it does not hold under the bandwidth-as-rows transpose that was rejected.
#
# WHY BINNED RECTANGLES INSTEAD OF RAW PER-EVENT RECTANGLES
# Each rank performs 200 MPI_Waitall cycles over the run. In this layout a
# panel is ~2in wide, i.e. well under 0.02in per iteration -- at or below
# print resolution. Raw per-event rectangles at that scale are sub-pixel, so
# the PDF rasteriser (not the data) decides which slivers survive: the
# apparent communication fraction would change with zoom level and viewer.
# Binning fixes this: each time bin is filled by the EXACT fraction of that
# interval each rank spent in each state, which is renderer-independent and
# is numerically the same quantity the Masking Effectiveness metric
# integrates (1 - comm ratio), just resolved over time instead of collapsed
# to a scalar.
#
# TIME AXIS: normalised to 0-100% of each run's analysis window, so all
# twelve panels share one temporal scale and the masked/exposed proportions
# are directly comparable. The absolute window length is NOT lost -- see the
# time band above.
#
# CATEGORIES: the four states of the reference figure are kept. Measured
# across the traces, MPI_Irecv + MPI_Isend together account for 0.0-0.4% of
# all communication time (MPI_Waitall is 99.6-100%): they are genuinely
# near-instantaneous, so they occupy a correspondingly invisible share here.
# That is faithful, not a simplification -- in the large raw-event figures the
# green/red slivers were minimum-width rendering artefacts, not real duration.
#
# "Compute" is INFERRED as the complement of the logged MPI_* intervals within
# each rank's window -- the Akypuera/PMPI trace only instruments MPI calls,
# there is no explicit Compute state. Same definition already used for the
# Masking Effectiveness metric. Stated in the caption, not hidden.
suppressMessages(library(tidyverse))

RESULTS_DIR <- "g5k/results"
FIG_DIR <- "analysis/results_package/figures"
N_BINS <- 120

FILL_COLORS <- c(Compute = "#F5D547", MPI_Irecv = "#4DAF4A", MPI_Isend = "#E41A1C", MPI_Waitall = "#377EB8")
FILL_LEVELS <- c("Compute", "MPI_Irecv", "MPI_Isend", "MPI_Waitall")
COMM_STATES <- c("MPI_Irecv", "MPI_Isend", "MPI_Waitall")
BAND_LABEL <- c("1gbit" = "1 Gbit/s", "10gbit" = "10 Gbit/s", "25gbit" = "25 Gbit/s")
BAND_ORDER <- c("1gbit", "10gbit", "25gbit")

# Full anchor roster (row 5 kept for when 5-node data exists -- NOT used
# below, since bench_*_5n_20g_N2340 has not been run yet; only nodes 1-4 have
# real data right now).
ANCHORS <- tribble(
  ~nodes, ~gpus,    ~N,
       1,     4,  1344,
       2,     8,  1728,
       3,    12,  1920,
       4,    16,  2176,
       5,    20,  2340
)
ANCHORS_DATA <- ANCHORS |> filter(nodes <= 4)

thr_raw <- read_csv("analysis/throughput_raw.csv", show_col_types = FALSE)

pick_representative_rep <- function(eid) {
  d <- thr_raw |> filter(experiment_id == eid, checkpoint_status == "done")
  if (nrow(d) == 0) stop(paste("No done reps for", eid))
  med <- median(d$total_time)
  d$rep[which.min(abs(d$total_time - med))]
}

# ---- load one rep's dc.csv, window-clipped exactly like masking_effectiveness.R
load_windowed_events <- function(eid, rep) {
  path <- file.path(RESULTS_DIR, eid, paste0("rep", rep), "dc.csv")
  df <- read_csv(path,
    col_names = c("Nature", "Container", "Type", "Start", "End", "Duration", "Imbrication", "Value"),
    col_types = cols(Nature = col_character(), Container = col_character(), Type = col_character(),
                      Start = col_double(), End = col_double(), Duration = col_double(),
                      Imbrication = col_double(), Value = col_character()),
    trim_ws = TRUE, progress = FALSE
  ) |>
    mutate(Container = str_trim(Container), Value = str_trim(Value))

  window_start <- df |> filter(Value == "MPI_Irecv") |> pull(Start) |> min(na.rm = TRUE)
  window_end   <- df |> filter(Value == "MPI_Waitall") |> pull(End) |> max(na.rm = TRUE)
  window_length <- window_end - window_start

  ranks <- df |> distinct(Container) |> arrange(Container) |> mutate(rank_idx = row_number() - 1)

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

# ---- fill the gaps between logged MPI intervals, per rank, with "Compute"
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

# ---- allocate each event's duration across the fixed-width bins it overlaps
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

# ---- (rank, bin, category) fractions -> stacked rectangles. Each rank owns
# [rank_idx, rank_idx+1) vertically, subdivided by category in FILL_LEVELS order.
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

one_cell <- function(nodes, gpus, N, band_key) {
  eid <- sprintf("bench_%s_%dn_%dg_N%d", band_key, nodes, gpus, N)
  rep_n <- pick_representative_rep(eid)
  loaded <- load_windowed_events(eid, rep_n)
  full_ev <- add_compute_gaps(loaded$events, loaded$window_length)
  rects <- to_rects(bin_events(full_ev, loaded$window_length))
  list(
    rects = rects |> mutate(nodes = nodes, band = band_key),
    meta = tibble(nodes = nodes, band = band_key, rep = rep_n,
                  n_ranks = loaded$n_ranks, window_length = loaded$window_length)
  )
}

grid <- expand_grid(ANCHORS_DATA, band = BAND_ORDER)
cells <- pmap(grid, function(nodes, gpus, N, band) one_cell(nodes, gpus, N, band))

rects <- map_dfr(cells, "rects")
meta  <- map_dfr(cells, "meta")

# ---- language variants ---------------------------------------------------
# Two full renders (PT/EN), identical data/layout/style, only visible text
# differs: node-count strip labels and the two axis titles. Everything else
# (band labels, legend categories, duration suffix "s") is already
# language-neutral and shared between both.
LANG_TEXT <- list(
  pt = list(
    node_fmt = "%d nó%s\nN = %d", node_suffix = "s",
    x_title = "Tempo decorrido [% da duração da execução]",
    y_title = "Rank MPI"
  ),
  en = list(
    node_fmt = "%d node%s\nN = %d", node_suffix = "s",
    x_title = "Elapsed time [% of run duration]",
    y_title = "MPI rank"
  )
)

# The GPU count is omitted from the strips on purpose -- it is 4 x nodes
# throughout the campaign, so it is fully determined by the node count and
# belongs in the caption, not in repeated strip labels.
node_label <- function(nodes, txt) {
  a <- ANCHORS_DATA[match(nodes, ANCHORS_DATA$nodes), ]
  sprintf(txt$node_fmt, nodes, ifelse(nodes > 1, txt$node_suffix, ""), a$N)
}

# ---- per-panel time band (language-independent geometry) ----------------
BAND_GAP <- 0.30   # blank gap between the top rank band and the time band
BAND_H   <- 1.35   # time-band height, in rank units

tband_base <- meta |>
  mutate(
    ymin = n_ranks + BAND_GAP,
    ymax = n_ranks + BAND_GAP + BAND_H,
    y_text = n_ranks + BAND_GAP + BAND_H / 2,
    lab = sprintf("%.0f s", window_length)
  )

build_timeline_matrix <- function(lang) {
  txt <- LANG_TEXT[[lang]]
  node_levels <- node_label(ANCHORS_DATA$nodes, txt)

  fct_cell <- function(d) {
    d |> mutate(
      nodes_label = factor(node_label(nodes, txt), levels = node_levels),
      band_label  = factor(BAND_LABEL[band], levels = BAND_LABEL[BAND_ORDER])
    )
  }
  rects_l <- fct_cell(rects)
  meta_l  <- fct_cell(meta)
  tband_l <- fct_cell(tband_base)

  p <- ggplot(rects_l) +
    geom_rect(
      data = tband_l, inherit.aes = FALSE,
      aes(xmin = 0, xmax = 1, ymin = ymin, ymax = ymax),
      fill = "grey90", colour = NA
    ) +
    geom_text(
      data = tband_l, inherit.aes = FALSE,
      aes(x = 0.985, y = y_text, label = lab),
      hjust = 1, vjust = 0.5, size = 1.95, colour = "grey20"
    ) +
    geom_rect(aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = Value)) +
    geom_rect(
      data = meta_l, inherit.aes = FALSE,
      aes(xmin = 0, xmax = 1, ymin = 0, ymax = n_ranks),
      fill = NA, colour = "grey45", linewidth = 0.25
    ) +
    facet_grid(nodes_label ~ band_label, scales = "free_y", space = "free_y", switch = "y") +
    scale_fill_manual(values = FILL_COLORS, limits = FILL_LEVELS, name = NULL, drop = FALSE) +
    # 0/50/100 only: with 25/75 as well, the trailing "100" of one panel and the
    # leading "0" of the next collide at this panel width.
    scale_x_continuous(breaks = c(0, 0.5, 1), labels = c("0", "50", "100"), expand = c(0, 0)) +
    # rank breaks come from the rank count, not the panel's upper limit (which
    # now includes the reserved time band)
    scale_y_continuous(
      breaks = function(l) {
        n <- round(l[2] - BAND_GAP - BAND_H)
        seq(0.5, n - 0.5, by = if (n <= 5) 1 else 4)
      },
      labels = function(b) as.integer(b - 0.5),
      expand = c(0, 0)
    ) +
    labs(x = txt$x_title, y = txt$y_title) +
    guides(fill = guide_legend(nrow = 1, keywidth = unit(8, "pt"), keyheight = unit(6, "pt"))) +
    theme_bw(base_size = 8) +
    theme(
      panel.grid = element_blank(),
      # 14pt: the trailing "100" of one panel and the leading "0" of the next
      # sit in different panels, so only the gap between them can separate the
      # two labels.
      panel.spacing.x = unit(14, "pt"),
      panel.spacing.y = unit(3, "pt"),
      panel.border = element_blank(),
      strip.background.x = element_rect(fill = "grey88", colour = NA),
      strip.background.y = element_blank(),
      strip.text.x = element_text(size = 7.4, colour = "grey10",
                                  margin = margin(2.5, 2.5, 2.5, 2.5)),
      strip.text.y.left = element_text(size = 6.8, angle = 0, colour = "grey15",
                                       hjust = 1, lineheight = 1.05,
                                       margin = margin(3, 4, 3, 1)),
      strip.placement = "outside",
      axis.text = element_text(size = 6.2, colour = "grey30"),
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

  fname <- sprintf("fig1_masking_timeline_matrix_%s", lang)
  ggsave(file.path(FIG_DIR, paste0(fname, ".pdf")), p, width = 7.0, height = 4.6, device = cairo_pdf)
  ggsave(file.path(FIG_DIR, paste0(fname, ".png")), p, width = 7.0, height = 4.6, dpi = 300)
  cat(sprintf("Wrote %s (7.0 x 4.6 in)\n", fname))
}

build_timeline_matrix("pt")
build_timeline_matrix("en")
