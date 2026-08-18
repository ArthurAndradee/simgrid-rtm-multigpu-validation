# shellcheck shell=bash
# ---------------------------------------------------------------------------
# checkpoint.sh — progress tracking + result-integrity verification + resume.
#
# Append-only log at $CHECKPOINTS_DIR/progress.csv (crash-safe: a partially
# written line at the tail from a killed job is simply the last, and its
# STATUS will never be "done" because that line is only appended AFTER
# run_experiment + integrity check both succeed).
#
# Format: experiment_id,rep,status,timestamp,result_dir,run_type
# status in {done, failed, timeout, oom, failed_permanent}
# run_type in {full, bench} — added 2026-07-15. Lines written before this
# date have only 5 columns; checkpoint_last_run_type treats a missing/empty
# 6th field as "full" (matches what every pre-existing recorded run actually
# was — the campaign had no bench-mode runs before --skip-output existed).
# tem_ground_truth is intentionally NOT a persisted column: it is a pure
# function of (topologia,N) and is recomputed on demand via
# csv_ground_truth_backends (single source of truth, no risk of drifting
# out of sync with the CSV).
# ---------------------------------------------------------------------------

: "${PROGRESS_FILE:=$CHECKPOINTS_DIR/progress.csv}"

checkpoint_init() {
  if [ ! -f "$PROGRESS_FILE" ]; then
    echo "experiment_id,rep,status,timestamp,result_dir,run_type" > "$PROGRESS_FILE"
  fi
}

# checkpoint_result_dir <experiment_id> <rep> — deterministic path.
checkpoint_result_dir() {
  echo "$RESULTS_DIR/$1/rep$2"
}

# checkpoint_last_status <experiment_id> <rep> — last recorded status, or
# empty if never attempted. Takes the LAST matching line (append-only log,
# so a re-run after a "failed" entry naturally supersedes it).
checkpoint_last_status() {
  local id=$1 rep=$2
  awk -F, -v id="$id" -v rep="$rep" \
    'NR>1 && $1==id && $2==rep { s=$3 } END { print s }' "$PROGRESS_FILE"
}

# checkpoint_last_run_type <experiment_id> <rep> — last recorded run_type,
# defaulting to "full" for legacy 5-column lines or if never attempted
# (matches pre-migration reality: every run before --skip-output existed
# was, by construction, a full run).
checkpoint_last_run_type() {
  local id=$1 rep=$2
  local rt
  rt=$(awk -F, -v id="$id" -v rep="$rep" \
    'NR>1 && $1==id && $2==rep { s=$6 } END { print s }' "$PROGRESS_FILE")
  echo "${rt:-full}"
}

# checkpoint_mark <experiment_id> <rep> <status> <result_dir> <run_type>
checkpoint_mark() {
  local id=$1 rep=$2 status=$3 dir=$4 run_type=$5
  [ -n "$run_type" ] || die "checkpoint_mark: run_type required (full|bench)"
  echo "$id,$rep,$status,$(date -Iseconds),$dir,$run_type" >> "$PROGRESS_FILE"
}

# checkpoint_integrity_ok <result_dir> <expected_np> <run_type> [expected_dc_bytes] [ground_truth_verdict]
#   run_type: full|bench — decides the .dc-presence/size check below.
#   expected_dc_bytes: REQUIRED when run_type=full (from csv_expected_dc_bytes);
#     ignored for bench.
#   ground_truth_verdict: optional, "pass"|"fail". Only meaningful for full
#     runs of a topology-representative that HAS ground truth available
#     (csv_ground_truth_backends non-empty) — the orchestrator computes this
#     by actually running CompareResults.R and passes the verdict in. If
#     omitted, no ground-truth check is applied here (bench reps, or full
#     reps of topologies with no ground truth possible — see design doc
#     5.0-quater/5.1-ter: 8 of 10 topology representatives have none, which
#     is a physical limit, not a gap in this check).
#
# Real verification, not just trusting the checkpoint file: dc.csv/dc.trace
# non-empty with real MPI states, rastro-*.rst count matches expected_np,
# dc.output has no known failure signature (the exact strings observed
# empirically for the pml_ucx_tls bug and CUDA init failures during
# on-hardware debugging), and (full only) predicted.dc exists with the
# exact expected byte size; (bench only) predicted.dc must NOT exist
# (--skip-output is expected to have produced none — its absence is itself
# evidence the flag actually worked, not just that no one looked).
checkpoint_integrity_ok() {
  local dir=$1 expected_np=$2 run_type=$3 expected_dc_bytes=${4:-} ground_truth_verdict=${5:-}

  case "$run_type" in
    full|bench) ;;
    *) die "checkpoint_integrity_ok: run_type must be full|bench, got '$run_type'" ;;
  esac

  [ -f "$dir/dc.output" ] || { warn "integrity: missing dc.output in $dir"; return 1; }
  [ -f "$dir/dc.csv" ]    || { warn "integrity: missing dc.csv in $dir"; return 1; }
  [ -f "$dir/dc.trace" ]  || { warn "integrity: missing dc.trace in $dir"; return 1; }
  [ -s "$dir/dc.csv" ]    || { warn "integrity: dc.csv is empty in $dir"; return 1; }
  [ -s "$dir/dc.trace" ]  || { warn "integrity: dc.trace is empty in $dir"; return 1; }

  grep -q '^State,' "$dir/dc.csv" \
    || { warn "integrity: dc.csv has no 'State,' lines in $dir"; return 1; }

  local n_rastros
  n_rastros=$(find "$dir" -maxdepth 1 -name 'rastro-*.rst' | wc -l)
  [ "$n_rastros" -eq "$expected_np" ] \
    || { warn "integrity: found $n_rastros rastro-*.rst, expected $expected_np, in $dir"; return 1; }

  # Known failure signatures observed empirically during on-hardware debugging
  # (sessions 1+2): a "done"-looking run that actually aborted mid-way.
  if grep -qE 'No components were able to be opened|CUDA Error|prterun has exited|MPI_ABORT' "$dir/dc.output"; then
    warn "integrity: dc.output contains a known failure signature in $dir"
    return 1
  fi

  if [ "$run_type" = full ]; then
    [ -n "$expected_dc_bytes" ] || die "checkpoint_integrity_ok: expected_dc_bytes required for run_type=full"
    if [ -f "$dir/predicted.dc" ]; then
      local actual_bytes
      actual_bytes=$(wc -c < "$dir/predicted.dc")
      [ "$actual_bytes" -eq "$expected_dc_bytes" ] \
        || { warn "integrity: predicted.dc size mismatch in $dir (got $actual_bytes, expected $expected_dc_bytes)"; return 1; }
    elif [ -f "$dir/predicted.dc.discarded" ]; then
      : # Validated-then-discarded by the "validar-e-descartar" retention
        # policy (design doc secao 5.1/9): the orchestrator writes this
        # marker ONLY after predicted.dc has already passed this exact
        # size check (and, where applicable, the ground-truth check)
        # once, right before deleting the (potentially huge) file. Its
        # presence is proof the check already succeeded, not an
        # exemption from it.
    else
      warn "integrity: run_type=full but neither predicted.dc nor predicted.dc.discarded present in $dir"
      return 1
    fi
    if [ -n "$ground_truth_verdict" ] && [ "$ground_truth_verdict" != pass ]; then
      warn "integrity: ground-truth numeric comparison did NOT pass in $dir (verdict=$ground_truth_verdict)"
      return 1
    fi
  else
    if [ -e "$dir/predicted.dc" ]; then
      warn "integrity: run_type=bench but predicted.dc EXISTS in $dir — --skip-output may not have taken effect"
      return 1
    fi
  fi

  return 0
}

# checkpoint_should_run <experiment_id> <rep> <expected_np> <run_type> [expected_dc_bytes] [ground_truth_verdict]
# — decides whether this rep needs to (re)run. Prints a one-word reason to
# stderr.
#   returns 0 (true, should run) if never attempted, marked failed, marked
#           done but integrity check fails (re-run just this rep), OR
#           marked done under a DIFFERENT run_type than currently expected
#           (defensive: this should never happen given the fixed campaign
#           structure — each experiment_id+rep maps deterministically to
#           one run_type — but a silent mismatch would be a worse bug than
#           a wasted re-run, so it is NOT tolerated silently)
#   returns 1 (false, skip) if marked done AND integrity holds AND run_type
#           matches
checkpoint_should_run() {
  local id=$1 rep=$2 expected_np=$3 run_type=$4 expected_dc_bytes=${5:-} ground_truth_verdict=${6:-}
  local status; status=$(checkpoint_last_status "$id" "$rep")
  local dir; dir=$(checkpoint_result_dir "$id" "$rep")

  if [ "$status" = "done" ]; then
    local last_run_type; last_run_type=$(checkpoint_last_run_type "$id" "$rep")
    if [ "$last_run_type" != "$run_type" ]; then
      warn "  rep$rep: marcado 'done' como run_type=$last_run_type mas esperado run_type=$run_type — reexecutando (possivel erro de classificacao)"
      return 0
    fi
    if checkpoint_integrity_ok "$dir" "$expected_np" "$run_type" "$expected_dc_bytes" "$ground_truth_verdict"; then
      log "  rep$rep: já concluído e íntegro — pulando"
      return 1
    else
      warn "  rep$rep: marcado 'done' mas resultado corrompido/incompleto — reexecutando"
      return 0
    fi
  fi
  return 0
}

# checkpoint_summary — quick campaign-progress report for the diary/CLI.
checkpoint_summary() {
  [ -f "$PROGRESS_FILE" ] || { echo "(nenhum checkpoint ainda)"; return; }
  awk -F, 'NR>1{c[$3]++} END{for(k in c) printf "  %s: %d\n", k, c[k]}' "$PROGRESS_FILE"
}
