# Shared functions for extracting pure CUDA kernel time (dc_compute_boundaries
# + dc_compute_interior) per iteration, per rank, from real-campaign dc.csv
# traces. See analysis/extract_kernel_time.R for the full rationale (why the
# uninstrumented gap between MPI calls equals real, cudaDeviceSynchronize()'d
# kernel time).
suppressMessages(library(tidyverse))

read_trace <- function(path) {
  read_csv(path,
    col_names = c("Nature", "Container", "Type", "Start", "End", "Duration", "Imbrication", "Value"),
    col_types = cols(
      Nature = col_character(), Container = col_character(), Type = col_character(),
      Start = col_double(), End = col_double(), Duration = col_double(),
      Imbrication = col_double(), Value = col_character()
    ),
    trim_ws = TRUE, progress = FALSE
  ) |>
    mutate(Container = str_trim(Container), Value = str_trim(Value))
}

# For one rank's Irecv/Isend/Waitall events (sorted by Start), walks the
# Irecv-run / Isend-run / Waitall / Waitall pattern once per iteration and
# returns the two compute gaps for each iteration found.
extract_rank_kernel_times <- function(df_rank) {
  vals <- df_rank$Value
  starts <- df_rank$Start
  ends <- df_rank$End

  n <- nrow(df_rank)
  i <- 1
  iterations <- list()
  iter_idx <- 0

  while (i <= n) {
    if (vals[i] != "MPI_Irecv") {
      i <- i + 1
      next
    }
    while (i <= n && vals[i] == "MPI_Irecv") i <- i + 1
    irecv_end <- ends[i - 1]
    if (i > n || vals[i] != "MPI_Isend") next

    isend_start <- starts[i]
    while (i <= n && vals[i] == "MPI_Isend") i <- i + 1
    isend_end <- ends[i - 1]
    if (i > n || vals[i] != "MPI_Waitall") next

    waitall1_start <- starts[i]
    waitall1_end <- ends[i]
    i <- i + 1
    if (i > n || vals[i] != "MPI_Waitall") next
    waitall2_start <- starts[i]
    i <- i + 1

    compute_boundaries_s <- isend_start - irecv_end
    compute_interior_s <- waitall1_start - isend_end
    # Bookkeeping (2026-08-13): the gap between the recv-Waitall's End and
    # the send-Waitall's Start is dc_worker_insert_halos() (x2) +
    # dc_device_swap_arrays() -- src/worker.c's per-iteration loop, real
    # host-side work (not network, not the propagate kernel) that
    # smpi/simulate-computation auto-times by default. Needed as its own
    # injectable constant (see DC_FIXED_BOOKKEEPING_S in worker.c) so that
    # disabling smpi/simulate-computation globally (to stop a memory-backing
    # artifact -- shared-malloc's cache-friendly "folded" pages made this
    # same bookkeeping run unrealistically fast, contaminating throughput,
    # confirmed live 2026-08-13) doesn't silently drop real, real-hardware
    # time from the simulated total.
    bookkeeping_s <- waitall2_start - waitall1_end

    iter_idx <- iter_idx + 1
    iterations[[iter_idx]] <- tibble(
      iteration = iter_idx,
      compute_boundaries_s = compute_boundaries_s,
      compute_interior_s = compute_interior_s,
      bookkeeping_s = bookkeeping_s,
      kernel_time_s = compute_boundaries_s + compute_interior_s
    )
  }
  bind_rows(iterations)
}

extract_kernel_times_from_files <- function(paths) {
  map_dfr(paths, function(path) {
    df <- read_trace(path)
    df |>
      filter(Value %in% c("MPI_Irecv", "MPI_Isend", "MPI_Waitall")) |>
      arrange(Container, Start) |>
      group_by(Container) |>
      group_modify(~ extract_rank_kernel_times(.x)) |>
      ungroup() |>
      mutate(source_file = path)
  })
}
