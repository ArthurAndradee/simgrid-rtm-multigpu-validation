# Strong-scaling counterpart of fig1_masking_timeline_matrix_{en,pt}
# (analysis/results_package/build_load_charts.R): same visual language, same
# binning, same window and same per-panel time band, applied to the 2026-10
# strong-scaling campaign (N = 968, native network, 101 shapes x 5 reps).
#
# LAYOUT: ROWS = process count (default np = 4 to 24, i.e. 1 to 6 chuc
# nodes), COLUMNS = best / median / worst partition shape of that np by mean
# throughput (analysis/strongscale_por_topologia.csv). Every panel of a row
# has the same rank count, so -- as in the original -- the time band renders
# at the same physical thickness across the row.
#
# Each panel shows the median-total_time rep of that shape (same rule as the
# original). The band above the panel gives the shape (left) and the panel's
# in-loop ME and window length (right).
#
# The helper functions below are copied unchanged from build_load_charts.R
# (that script runs at top level and regenerates the paper figure when
# sourced, so it is not sourced here). The original figure is not touched;
# outputs use new file names.
#
# The traces (dc.csv) are not in the repository; point RESULTS_DIR at the
# campaign's g5k/results directory:
#   RESULTS_DIR=/path/to/g5k/results \
#     Rscript campanha-2026-10/artigo_novos_dados/build_figura2_strongscale_real.R
# 4-row variant (np = 4, 8, 16, 24, as in the paper figure):
#   NP_ROWS=4,8,16,24 OUT_SUFFIX=_4linhas RESULTS_DIR=... Rscript ...
suppressMessages(library(tidyverse))

RESULTS_DIR <- Sys.getenv("RESULTS_DIR", "g5k/results")
FIG_DIR <- "campanha-2026-10/artigo_novos_dados"
N_BINS <- 120
# NP_ROWS env: comma-separated np list (default 4,8,12,16,20,24); OUT_SUFFIX is appended to the file names so
# variants never overwrite each other.
NP_ROWS <- as.integer(strsplit(Sys.getenv("NP_ROWS", "4,8,12,16,20,24"), ",")[[1]])
OUT_SUFFIX <- Sys.getenv("OUT_SUFFIX", "")
GPUS_PER_NODE <- 4

FILL_COLORS <- c(Compute = "#F5D547", MPI_Irecv = "#4DAF4A", MPI_Isend = "#E41A1C", MPI_Waitall = "#377EB8")
FILL_LEVELS <- c("Compute", "MPI_Irecv", "MPI_Isend", "MPI_Waitall")
COMM_STATES <- c("MPI_Irecv", "MPI_Isend", "MPI_Waitall")
CHOICE_ORDER <- c("best", "median", "worst")

topo <- read_csv("analysis/strongscale_por_topologia.csv", show_col_types = FALSE)
per_rep <- read_csv("analysis/strongscale_por_rep.csv", show_col_types = FALSE)

# best / median / worst shape of each np by mean throughput; "median" = the
# shape whose mean throughput is closest to the median of that np's shapes
choices <- topo |>
  filter(np %in% NP_ROWS) |>
  group_by(np) |>
  summarise(
    best = experiment_id[which.max(throughput_mean)],
    median = experiment_id[which.min(abs(throughput_mean - median(throughput_mean)))],
    worst = experiment_id[which.min(throughput_mean)],
    .groups = "drop"
  ) |>
  pivot_longer(all_of(CHOICE_ORDER), names_to = "choice", values_to = "experiment_id") |>
  left_join(topo |> select(experiment_id, dims, throughput_mean, me_mean), by = "experiment_id")

pick_representative_rep <- function(eid) {
  d <- per_rep |> filter(experiment_id == eid)
  if (nrow(d) == 0) stop(paste("No reps for", eid))
  med <- median(d$total_time_s)
  d$rep[which.min(abs(d$total_time_s - med))]
}

# ---- copied from build_load_charts.R ------------------------------------
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

  # rank order by number, not by string ("rank10" must come after "rank9")
  ranks <- df |> distinct(Container) |>
    mutate(rank_num = as.integer(str_extract(Container, "[0-9]+"))) |>
    arrange(rank_num) |> mutate(rank_idx = row_number() - 1) |> select(-rank_num)

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
# ---- end of copied helpers ------------------------------------------------

one_cell <- function(np, choice, experiment_id, dims, me_mean) {
  rep_n <- pick_representative_rep(experiment_id)
  loaded <- load_windowed_events(experiment_id, rep_n)
  full_ev <- add_compute_gaps(loaded$events, loaded$window_length)
  rects <- to_rects(bin_events(full_ev, loaded$window_length))
  list(
    rects = rects |> mutate(np = np, choice = choice),
    meta = tibble(np = np, choice = choice, dims = dims, me_mean = me_mean, rep = rep_n,
                  n_ranks = loaded$n_ranks, window_length = loaded$window_length)
  )
}

cells <- pmap(choices |> select(np, choice, experiment_id, dims, me_mean), one_cell)
rects <- map_dfr(cells, "rects")
meta  <- map_dfr(cells, "meta")
write_csv(meta, file.path(FIG_DIR, sprintf("figura2_strongscale_real%s_paineis.csv", OUT_SUFFIX)))

LANG_TEXT <- list(
  pt = list(
    np_fmt = "np = %d\n%d nó%s", node_suffix = "s",
    choice = c(best = "Melhor forma", median = "Forma mediana", worst = "Pior forma"),
    x_title = "Tempo decorrido [% da janela do laço]",
    y_title = "Rank MPI", dec = ","
  ),
  en = list(
    np_fmt = "np = %d\n%d node%s", node_suffix = "s",
    choice = c(best = "Best shape", median = "Median shape", worst = "Worst shape"),
    x_title = "Elapsed time [% of time-loop window]",
    y_title = "MPI rank", dec = "."
  )
)

np_label <- function(np, txt) {
  nodes <- np / GPUS_PER_NODE
  sprintf(txt$np_fmt, np, nodes, ifelse(nodes > 1, txt$node_suffix, ""))
}

BAND_GAP <- 0.30
BAND_H   <- 1.35

build_timeline_matrix <- function(lang) {
  txt <- LANG_TEXT[[lang]]
  np_levels <- np_label(NP_ROWS, txt)
  fct_cell <- function(d) {
    d |> mutate(
      np_label = factor(np_label(np, txt), levels = np_levels),
      choice_label = factor(txt$choice[choice], levels = txt$choice[CHOICE_ORDER])
    )
  }
  # fixed height in rank units: with space = "free_y" one rank unit has the
  # same physical size in every row, so the band is equally thick everywhere
  tband <- meta |>
    mutate(
      ymin = n_ranks + BAND_GAP, ymax = n_ranks + BAND_GAP + BAND_H,
      y_text = n_ranks + BAND_GAP + BAND_H / 2,
      lab_left = dims,
      lab_right = paste0("ME ", formatC(me_mean, format = "f", digits = 2, decimal.mark = txt$dec),
                         " · ", formatC(window_length, format = "f", digits = 1, decimal.mark = txt$dec), " s")
    )
  rects_l <- fct_cell(rects)
  meta_l  <- fct_cell(meta)
  tband_l <- fct_cell(tband)

  p <- ggplot(rects_l) +
    geom_rect(data = tband_l, inherit.aes = FALSE,
              aes(xmin = 0, xmax = 1, ymin = ymin, ymax = ymax), fill = "grey90", colour = NA) +
    geom_text(data = tband_l, inherit.aes = FALSE,
              aes(x = 0.015, y = y_text, label = lab_left),
              hjust = 0, vjust = 0.5, size = 1.95, colour = "grey10", fontface = "bold") +
    geom_text(data = tband_l, inherit.aes = FALSE,
              aes(x = 0.985, y = y_text, label = lab_right),
              hjust = 1, vjust = 0.5, size = 1.95, colour = "grey20") +
    geom_rect(aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = Value)) +
    geom_rect(data = meta_l, inherit.aes = FALSE,
              aes(xmin = 0, xmax = 1, ymin = 0, ymax = n_ranks),
              fill = NA, colour = "grey45", linewidth = 0.25) +
    facet_grid(np_label ~ choice_label, scales = "free_y", space = "free_y", switch = "y") +
    scale_fill_manual(values = FILL_COLORS, limits = FILL_LEVELS, name = NULL, drop = FALSE) +
    scale_x_continuous(breaks = c(0, 0.5, 1), labels = c("0", "50", "100"), expand = c(0, 0)) +
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
      panel.spacing.x = unit(14, "pt"),
      panel.spacing.y = unit(3, "pt"),
      panel.border = element_blank(),
      strip.background.x = element_rect(fill = "grey88", colour = NA),
      strip.background.y = element_blank(),
      strip.text.x = element_text(size = 7.4, colour = "grey10", margin = margin(2.5, 2.5, 2.5, 2.5)),
      strip.text.y.left = element_text(size = 6.8, angle = 0, colour = "grey15",
                                       hjust = 1, lineheight = 1.05, margin = margin(3, 4, 3, 1)),
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
      plot.margin = margin(2, 9, 1, 2)
    )

  fname <- sprintf("figura2_strongscale_real%s_%s", OUT_SUFFIX, lang)
  # height proportional to total rank units, calibrated on the 4-row layout
  # (np 4/8/16/24 -> 5.8 in)
  units <- sum(NP_ROWS) + length(NP_ROWS) * (BAND_GAP + BAND_H)
  height <- round(5.8 * units / (52 + 4 * (BAND_GAP + BAND_H)), 1)
  ggsave(file.path(FIG_DIR, paste0(fname, ".pdf")), p, width = 7.0, height = height, device = cairo_pdf)
  ggsave(file.path(FIG_DIR, paste0(fname, ".png")), p, width = 7.0, height = height, dpi = 300)
  cat(sprintf("Wrote %s (7.0 x %.1f in)\n", fname, height))
}

build_timeline_matrix("pt")
build_timeline_matrix("en")
