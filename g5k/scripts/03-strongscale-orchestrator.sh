#!/usr/bin/env bash
# scripts/03-strongscale-orchestrator.sh — Idea 1 (strong scaling) campaign.
# Reads g5k/csv/strongscale_experiments.csv (101 ordered-triple partition
# shapes x np in {1,2,4,8,12,16,20,24}, all at fixed N=968) and runs each
# row x REPS_PER_EXPERIMENT reps, native bandwidth (no tc shaping -- this
# campaign targets partition-shape/compute-coalescence effects, not network
# bandwidth; see campanha-2026-10/README.md), --skip-output (bench-mode
# timing only, same convention as the bandwidth-sweep campaign's bench
# phase). Reuses lib/{core,checkpoint,run,shape,csv}.sh rather than
# reimplementing hostfile/checkpoint/run machinery -- csv_gpu_distribution,
# csv_row_fits_gpu_capacity and csv_cli_size are generic (not tied to the
# bandwidth-sweep CSV's column layout), the rest of lib/csv.sh is unused here.
#
# All 101 configurations are run explicitly, no equivalence-class reduction
# (the strong-scaling study is exhaustive by design).
#
# Usage (after ./scripts/01-bootstrap.sh, from g5k/, OAR_JOB_ID exported):
#   ./scripts/03-strongscale-orchestrator.sh                # all rows
#   ./scripts/03-strongscale-orchestrator.sh --dry-run       # print plan only
#   ./scripts/03-strongscale-orchestrator.sh --only-id <experiment_id>
#   ./scripts/03-strongscale-orchestrator.sh --np 24          # only np=24 rows
#
# Safe to interrupt and re-run: checkpoint_should_run skips already-done+
# integrity-verified reps (lib/checkpoint.sh, same schema/semantics as the
# bandwidth-sweep orchestrator's bench phase, run_type="bench").
set -euo pipefail
cd "$(dirname "$0")/.."   # -> g5k/
source ./lib/core.sh
source ./conf/defaults.conf
source ./lib/csv.sh
source ./lib/shape.sh
source ./lib/run.sh
source ./lib/checkpoint.sh

SS_CSV="$CSV_DIR/strongscale_experiments.csv"
[ -s "$SS_CSV" ] || die "$SS_CSV missing/empty"
header=$(head -n1 "$SS_CSV")
[ "$header" = "experiment_id,np,dims_str,N,local_x,local_y,local_z" ] \
  || die "unexpected strongscale CSV header: $header"

DRY_RUN=0
ONLY_ID=""
ONLY_NP=""
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) DRY_RUN=1; shift ;;
    --only-id) ONLY_ID=$2; shift 2 ;;
    --np) ONLY_NP=$2; shift 2 ;;
    *) die "unknown option $1" ;;
  esac
done

require_nodes_file
checkpoint_init

LOCK_FILE="$STATE_DIR/strongscale_orchestrator.lock"
if [ -f "$LOCK_FILE" ]; then
  old_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
  if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
    die "Outro orquestrador de strong-scaling ja em execucao (PID $old_pid)."
  fi
  warn "Lock obsoleto (PID ${old_pid:-?} morto) -- removendo."
fi
echo $$ > "$LOCK_FILE"
if [ "$DRY_RUN" -eq 0 ]; then
  trap 'rm -f "$LOCK_FILE"; shape_off >/dev/null 2>&1 || true' EXIT
  shape_off   # this campaign is native-only; refuse to inherit stale shaping
else
  trap 'rm -f "$LOCK_FILE"' EXIT
fi

AVAIL=$(node_count)
log "Nos disponiveis: $AVAIL ($(nodes | paste -sd', ')) | GPUs/no esperado: $EXPECTED_GPUS_PER_NODE | REPS: $REPS_PER_EXPERIMENT"
MAX_NP=$((AVAIL * EXPECTED_GPUS_PER_NODE))
log "np maximo alcancavel nesta alocacao: $MAX_NP"

N_SKIPPED_DONE=0
N_SKIPPED_DEFER=0
N_RUN_OK=0
N_RUN_FAILED=0

# ss_build_hostfile <np> <hostfile_path> -- nodes_needed = ceil(np/EXPECTED_GPUS_PER_NODE),
# ranks distributed largest-remainder (csv_gpu_distribution) across the
# first nodes_needed nodes from nodes() (deterministic order).
ss_build_hostfile() {
  local np=$1 hostfile=$2
  local nodes_needed=$(( (np + EXPECTED_GPUS_PER_NODE - 1) / EXPECTED_GPUS_PER_NODE ))
  [ "$nodes_needed" -le "$AVAIL" ] || return 1
  csv_row_fits_gpu_capacity "$nodes_needed" "$np" || return 1
  local -a selected dist
  mapfile -t selected < <(nodes | head -n "$nodes_needed")
  read -ra dist <<< "$(csv_gpu_distribution "$nodes_needed" "$np")"
  : > "$hostfile"
  local i
  for i in "${!selected[@]}"; do
    [ "${dist[$i]}" -gt 0 ] && echo "${selected[$i]} slots=${dist[$i]}" >> "$hostfile"
  done
}

while IFS=, read -r exp_id np dims_str n local_x local_y local_z; do
  [ "$exp_id" = "experiment_id" ] && continue
  [ -z "$exp_id" ] && continue
  if [ -n "$ONLY_ID" ] && [ "$exp_id" != "$ONLY_ID" ]; then continue; fi
  if [ -n "$ONLY_NP" ] && [ "$np" != "$ONLY_NP" ]; then continue; fi

  if [ "$np" -gt "$MAX_NP" ]; then
    [ "$DRY_RUN" -eq 1 ] || warn "SS $exp_id: np=$np > maximo alcancavel $MAX_NP -- DEFER"
    N_SKIPPED_DEFER=$((N_SKIPPED_DEFER + 1))
    continue
  fi

  size_cli=$(csv_cli_size "$n")
  topology_arg=${dims_str//x/,}
  hostfile="$STATE_DIR/.hostfile_ss_${exp_id}"

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] SS $exp_id: np=$np topology=$topology_arg N=$n size_cli=$size_cli local=${local_x}x${local_y}x${local_z} x $REPS_PER_EXPERIMENT reps"
    continue
  fi

  if ! ss_build_hostfile "$np" "$hostfile"; then
    warn "SS $exp_id: np=$np nao cabe na capacidade real de GPU dos $AVAIL no(s) disponivel(is) -- DEFER"
    N_SKIPPED_DEFER=$((N_SKIPPED_DEFER + 1))
    continue
  fi

  for rep in $(seq 1 "$REPS_PER_EXPERIMENT"); do
    if ! checkpoint_should_run "$exp_id" "$rep" "$np" bench; then
      N_SKIPPED_DONE=$((N_SKIPPED_DONE + 1))
      continue
    fi

    remaining=""
    remaining=$(oar_walltime_remaining_s 2>/dev/null) || remaining=""
    # Defer unless a full run budget fits before the margin: starting a rep
    # with only a few seconds of timeout left just gets it killed (and a 0s
    # timeout means "no limit" to run_experiment).
    if [ -n "$remaining" ] && [ "$remaining" -lt $((MIN_WALLTIME_MARGIN_S + MIN_RUN_BUDGET_S)) ]; then
      warn "SS $exp_id rep$rep: DEFER -- apenas ${remaining}s de walltime restante (< margem ${MIN_WALLTIME_MARGIN_S}s + orcamento ${MIN_RUN_BUDGET_S}s)"
      N_SKIPPED_DEFER=$((N_SKIPPED_DEFER + 1))
      continue
    fi

    result_dir=$(checkpoint_result_dir "$exp_id" "$rep")
    rm -rf "$result_dir"; mkdir -p "$result_dir"

    RUN_HOSTFILE=$hostfile RUN_NP=$np RUN_NATIVE=1 RUN_RESULT_DIR=$result_dir
    if [ -n "$remaining" ]; then
      RUN_TIMEOUT_S=$((remaining - MIN_WALLTIME_MARGIN_S))
    else
      RUN_TIMEOUT_S=0
    fi
    RUN_APP_ARGS=(--size-x="$size_cli" --size-y="$size_cli" --size-z="$size_cli" \
                   --absorption="$ABSORPTION" --dx="$DC_DX" --dy="$DC_DY" --dz="$DC_DZ" \
                   --dt="$DC_DT" --time-max="$DC_TIME_MAX" --skip-output \
                   --topology="$topology_arg")

    log "--- SS $exp_id rep$rep/$REPS_PER_EXPERIMENT (np=$np, topology=$topology_arg) ---"
    rc=0
    run_experiment || rc=$?

    if [ "$rc" -eq 0 ] && checkpoint_integrity_ok "$result_dir" "$np" bench; then
      checkpoint_mark "$exp_id" "$rep" done "$result_dir" bench
      N_RUN_OK=$((N_RUN_OK + 1))
    else
      status=failed
      [ "$rc" -eq 124 ] && status=timeout
      checkpoint_mark "$exp_id" "$rep" "$status" "$result_dir" bench
      warn "$exp_id rep$rep FALHOU (rc=$rc, status=$status) -- ver $result_dir/dc.output"
      N_RUN_FAILED=$((N_RUN_FAILED + 1))
    fi
  done
done < <(tail -n +2 "$SS_CSV")

log "=== Campanha strong-scaling (esta execucao) concluida ==="
log "  OK: $N_RUN_OK | Falhas: $N_RUN_FAILED | Pulados (ja integros): $N_SKIPPED_DONE | Adiados (np/walltime): $N_SKIPPED_DEFER"
checkpoint_summary

if [ "$N_RUN_FAILED" -gt 0 ]; then
  warn "Ha $N_RUN_FAILED repeticao(oes) com falha/timeout -- reexecute (retenta automaticamente)."
  exit 1
fi
