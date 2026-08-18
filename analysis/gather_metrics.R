suppressMessages(library(tidyverse))
library(stringr)

# Adapted from the original Spadotto layout (analysis/2026-03-18/<run>/<size>/dc.output)
# to the g5k campaign layout: results/<experiment_id>/rep<N>/dc.output. experiment_id
# already encodes bandwidth/nodes/gpus/topology/N (see g5k/csv/experimentos.csv), so
# grouping is done by experiment_id rather than by problem_size alone.
#
# checkpoint_status is joined in from g5k/checkpoints/progress.csv rather than
# inferred from file presence: a rep can have a fully valid dc.output (the MPI
# run and its timing completed) while still being checkpointed "failed" because
# trace collection failed independently (e.g. the known Akypuera/1gbit crash,
# which leaves an empty dc.csv but a valid dc.output). Filtering is left to the
# consumer -- this script reports status rather than silently dropping or
# silently including those reps.
args <- commandArgs(trailingOnly = TRUE)
base_dir <- if (length(args) >= 1) args[1] else "g5k/results"
output_csv <- if (length(args) >= 2) args[2] else "analysis/throughput_raw.csv"
checkpoint_csv <- if (length(args) >= 3) args[3] else "g5k/checkpoints/progress.csv"

if (!dir.exists(base_dir)) {
    stop(paste("Directory not found:", base_dir))
}

load_checkpoint_status <- function(path) {
    if (!file.exists(path)) {
        warning(paste("Checkpoint file not found, checkpoint_status will be NA:", path))
        return(NULL)
    }
    # progress.csv is ragged: older rows (pre-full/bench split) have 5 fields,
    # newer ones have 6 (run_type appended). Declaring all 6 columns by name
    # (rather than relying on col_types = cols(.default = ...), which infers
    # column count from the first rows and then flags the 6-field rows as
    # parsing errors) makes readr pad the missing run_type with NA instead.
    read_csv(path,
        col_names = c("experiment_id", "rep", "status", "timestamp", "result_dir", "run_type"),
        col_types = cols(
            experiment_id = col_character(), rep = col_character(), status = col_character(),
            timestamp = col_character(), result_dir = col_character(), run_type = col_character()
        ), skip = 1, progress = FALSE
    ) |>
        mutate(rep = as.integer(rep)) |>
        # progress.csv is append-only: a rep can have multiple rows across
        # retries, so keep only the most recent status per (experiment_id, rep).
        group_by(experiment_id, rep) |>
        slice_max(timestamp, n = 1, with_ties = FALSE) |>
        ungroup() |>
        select(experiment_id, rep, checkpoint_status = status)
}

checkpoint_status <- load_checkpoint_status(checkpoint_csv)

files <- list.files(path = base_dir, pattern = "dc\\.output$", recursive = TRUE, full.names = TRUE)

if (length(files) == 0) {
    warning("No dc.output files found.")
}

parse_output <- function(file_path) {
    path_parts <- str_match(file_path, "/([^/]+)/rep([0-9]+)/dc\\.output$")

    if (any(is.na(path_parts))) {
        warning(paste("Could not parse path structure for:", file_path))
        return(NULL)
    }

    experiment_id <- path_parts[2]
    rep <- as.integer(path_parts[3])

    lines <- readLines(file_path, warn = FALSE)
    header_idx <- grep("^rank,total_time,msamples_per_s", lines)

    if (length(header_idx) > 0) {
        csv_lines <- lines[header_idx[1]:length(lines)]
        df <- read.csv(text = paste(csv_lines, collapse = "\n"), colClasses = c("rank" = "character"))
        df_rank0 <- df[df$rank == "*", ]
        if (nrow(df_rank0) > 0) {
            # tibble(), not data.frame(): print(x, n = Inf) further down
            # partially matches "n" to print.data.frame's "na.print" on a
            # plain data.frame, crashing with "invalid 'na.print' specification".
            return(tibble(
                experiment_id = experiment_id, rep = rep,
                total_time = df_rank0$total_time[1], msamples_per_s = df_rank0$msamples_per_s[1]
            ))
        }
    }

    NULL
}

df <- map_dfr(files, parse_output)
if (nrow(df) > 0) {
    if (!is.null(checkpoint_status)) {
        df <- df |> left_join(checkpoint_status, by = c("experiment_id", "rep"))
    } else {
        df <- df |> mutate(checkpoint_status = NA_character_)
    }
    df <- df |> arrange(experiment_id, rep)

    dir.create(dirname(output_csv), showWarnings = FALSE, recursive = TRUE)
    write_csv(df, output_csv)
    cat(sprintf("Wrote %d rows (raw, per-rep) to %s\n\n", nrow(df), output_csv))

    not_done <- df |> filter(is.na(checkpoint_status) | checkpoint_status != "done")
    if (nrow(not_done) > 0) {
        cat(sprintf(
            "NOTE: %d of %d rows have a valid dc.output but checkpoint_status != 'done' (e.g. trace-only failures like the known Akypuera/1gbit crash). They are INCLUDED in throughput_raw.csv with their status labeled -- filter on checkpoint_status before treating them as part of the official campaign.\n\n",
            nrow(not_done), nrow(df)
        ))
        print(not_done |> select(experiment_id, rep, checkpoint_status), n = Inf)
        cat("\n")
    }

    summary_df <- df |>
        filter(checkpoint_status == "done") |>
        group_by(experiment_id) |>
        summarise(reps_done = n(), total_time = mean(total_time), msamples_per_s = mean(msamples_per_s), .groups = "drop")

    cat("Summary below uses ONLY checkpoint_status == 'done' reps:\n")
    print(summary_df, n = Inf)
} else {
    print("No data parsed.")
}
