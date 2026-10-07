#!/usr/bin/env bash
# scripts/02-orchestrator.sh — reads experiments.csv and runs the campaign
# in two decoupled phases (see design doc g5k/logs/campaign_infrastructure_design.md on main,
# secao 5.0-quater — this is the FIXED premise of the project as of
# 2026-07-15, not a placeholder):
#
#   full  — exactly 1 execution per DISTINCT MPI topology (not per CSV row),
#           always at that topology's smallest Tamanho_Global_N, run NATIVE
#           (never shaped — the .dc result does not depend on bandwidth,
#           see design doc secao 5.0). Produces --output-file; where
#           physically possible (np=1 fits in VRAM/RAM — csv_ground_truth_
#           backends), also runs an independent np=1 OpenMP reference and
#           compares via CompareResults.R. Where not possible (8 of 10
#           topologies — a hard N^3-memory limit, not a policy choice),
#           the only numeric evidence is deterministic reproducibility
#           between reps (already established empirically: same seed,
#           bit-identical results) — an accepted, explicitly documented
#           threat to validity, NOT silently glossed over.
#   bench — every (banda,topologia,N) row x REPS_PER_EXPERIMENT, shaped,
#           --skip-output (skips gather+write, both AFTER the measured
#           window — see design doc secao 3). Collects timing/masking
#           metrics only (mean, stdev across reps). Never touches ground
#           truth or .dc files.
#
# Usage (after ./scripts/01-bootstrap.sh has succeeded, OAR_JOB_ID exported):
#   export OAR_JOB_ID=<jobid>
#   ./scripts/02-orchestrator.sh                    # phase=all (full then bench)
#   ./scripts/02-orchestrator.sh --phase full       # only the 10 full runs
#   ./scripts/02-orchestrator.sh --phase bench      # only the 105x5 bench runs
#   ./scripts/02-orchestrator.sh --dry-run          # print the execution plan only
#   ./scripts/02-orchestrator.sh --only-id <experiment_id>   # single experiment (debug)
#   ./scripts/02-orchestrator.sh --bandwidths 25gbit,10gbit  # bench phase only:
#       process just these bandwidths, in this order, instead of the default
#       1gbit,10gbit,25gbit — for backfilling a bandwidth left behind by a
#       previous session (the default loop order always finishes 1gbit
#       deepest if interrupted). Omit the flag to keep prior behavior exactly.
#
# Safe to interrupt (Ctrl-C, walltime expiry, SSH drop) and re-run later:
# an inflight.txt marker + orphan-process sweep reconcile any run that was
# abandoned mid-way (see lib/resilience.sh); already "done"-and-integrity-
# verified repetitions are skipped (see lib/checkpoint.sh). A PID lock
# (state/orchestrator.lock) refuses a second concurrent orchestrator.
set -euo pipefail
cd "$(dirname "$0")/.."   # -> g5k/
source ./lib/core.sh
source ./conf/defaults.conf
source ./lib/setup.sh
source ./lib/resilience.sh
source ./lib/shape.sh
source ./lib/run.sh
source ./lib/csv.sh
source ./lib/validate.sh
source ./lib/checkpoint.sh
source ./lib/sciencelog.sh

DRY_RUN=0
ONLY_ID=""
PHASE=all
BANDWIDTHS_ARG=""
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) DRY_RUN=1; shift ;;
    --only-id) ONLY_ID=$2; shift 2 ;;
    --phase) PHASE=$2; shift 2 ;;
    --bandwidths) BANDWIDTHS_ARG=$2; shift 2 ;;
    *) die "unknown option $1" ;;
  esac
done
case "$PHASE" in
  full|bench|all) ;;
  *) die "--phase must be full|bench|all, got '$PHASE'" ;;
esac

require_nodes_file
csv_selfcheck
checkpoint_init

# --- Lock: refuse a second concurrent orchestrator --------------------
LOCK_FILE="$STATE_DIR/orchestrator.lock"
if [ -f "$LOCK_FILE" ]; then
  old_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
  if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
    die "Outro orquestrador já em execução (PID $old_pid, ver $LOCK_FILE). Aguarde ou finalize-o antes de iniciar outro."
  fi
  warn "Lock obsoleto encontrado (PID ${old_pid:-?} não está mais vivo) — removendo e prosseguindo."
fi
echo $$ > "$LOCK_FILE"

# Single combined EXIT trap (a second `trap ... EXIT` would silently
# REPLACE this one, not add to it — bash traps are not cumulative).
# Lock cleanup always runs; shape_off is also run (best-effort) unless
# this is a --dry-run, which never calls shape_apply in the first place.
#
# Shaping-cleanup rationale: any die()/crash/SIGTERM (walltime expiry,
# killed shell, VSCode/session teardown — all observed empirically this
# session) between shape_apply and the phase's own shape_off left tc
# rules dangling on the nodes, blocking the NEXT invocation's native
# preflight smoke test (RUN_NATIVE=1 refuses to run under active shaping
# — correct guard, wrong UX: it should self-heal, not require a manual
# shape_off). shape_off's own ssh calls degrade gracefully on unreachable
# nodes, and it is harmless when shaping is already off. Gap found and
# fixed 2026-07-17, job 2169626, after hitting it 3 times in one
# allocation.
if [ "$DRY_RUN" -eq 0 ]; then
  trap 'rm -f "$LOCK_FILE"; shape_off >/dev/null 2>&1 || true' EXIT
else
  trap 'rm -f "$LOCK_FILE"' EXIT
fi

# --- Resume: reconcile any run abandoned by a previous crashed orchestrator
if resumed=$(inflight_resume); then
  IFS=$'\t' read -r r_id r_rep r_run_type r_dir <<< "$resumed"
  warn "Retomando após interrupção anterior: $r_id rep$r_rep ($r_run_type, $r_dir) — marcando como failed (será retentado nesta execução)."
  checkpoint_mark "$r_id" "$r_rep" failed "$r_dir" "$r_run_type"
  diary "Orquestrador anterior interrompido em $r_id rep$r_rep ($r_run_type). Reconciliado: órfãos varridos, marcado failed para retentativa."
fi

AVAIL=$(node_count)
TOTAL_ROWS=$(csv_count_rows)
COMPAT_ROWS=$(csv_count_compatible_rows "$AVAIL")
log "Nós disponíveis: $AVAIL | Linhas do CSV: $TOTAL_ROWS | Compatíveis: $COMPAT_ROWS | Fase: $PHASE"
[ "$COMPAT_ROWS" -gt 0 ] || die "Nenhuma linha do CSV é compatível com $AVAIL nó(s) disponível(is). Nada a fazer."

if [ "$DRY_RUN" -eq 0 ]; then
  validate_campaign_preflight
fi
diary "Orquestrador iniciado. $AVAIL nós disponíveis, $COMPAT_ROWS/$TOTAL_ROWS linhas compatíveis. phase=$PHASE dry_run=$DRY_RUN only_id=${ONLY_ID:-<todos>} bandwidths=${BANDWIDTHS_ARG:-<padrão 1gbit,10gbit,25gbit>}"

# Default fixed progression (matches the validated g5k/06-sweep.sh
# convention) — --bandwidths lets THIS invocation process a different
# subset/order (e.g. to backfill a bandwidth left behind by a previous,
# interrupted session) without touching any experiment logic, checkpoint
# schema, or the default behavior when the flag is omitted. [ADD]
# 2026-07-20, requested to correct a real coverage imbalance found by
# campaign audit (1gbit far ahead of 10gbit/25gbit after a walltime cutoff
# landed mid-sweep — the fixed loop order means an interrupted campaign
# always finishes 1gbit deepest, never balanced across bands).
if [ -n "$BANDWIDTHS_ARG" ]; then
  IFS=',' read -r -a BANDWIDTHS <<< "$BANDWIDTHS_ARG"
  for b in "${BANDWIDTHS[@]}"; do
    case "$b" in
      1gbit|10gbit|25gbit) ;;
      *) die "--bandwidths: valor inválido '$b' (esperado 1gbit, 10gbit ou 25gbit)" ;;
    esac
  done
else
  BANDWIDTHS=(1gbit 10gbit 25gbit)
fi
N_SKIPPED_VRAM=0
N_SKIPPED_DONE=0
N_SKIPPED_DEFER=0
N_RUN_OK=0
N_RUN_FAILED=0

# handle_run_failure <rc> <result_dir> — after ANY failed/timeout rep:
# sweep orphans defensively (the run may have left processes on worker
# nodes), and if dc.output shows a connectivity-failure signature,
# reactively re-probe node liveness so the NEXT row/rep's compatible-row
# filtering and hostfile construction reflect reality (design doc secao 8:
# nodes_liveness_probe is reactive-only, triggered here, not periodic).
handle_run_failure() {
  local rc=$1 dir=$2
  orphan_cleanup
  [ "$rc" -eq 124 ] && return 0   # timeout alone isn't a connectivity signature
  if grep -qE 'Connection refused|No route to host|ssh_exchange_identification|Broken pipe' "$dir/dc.output" 2>/dev/null; then
    warn "handle_run_failure: assinatura de falha de conectividade em $dir/dc.output — re-censo reativo de nós"
    nodes_liveness_probe >/dev/null
    AVAIL=$(node_count)
  fi
}

# run_ground_truth_check <topologia> <n> <size_cli> <predicted_dc_path> <result_dir>
# — builds (once, cached) an isolated OpenMP reference binary at
# bin_openmp_gt/dc (Makefile's BUILDDIR override — confirmed
# 2026-07-15 this does NOT touch bin/dc, the campaign's CUDA binary),
# runs it np=1 with the SAME physical parameters, and compares its output
# against the full run's predicted.dc via CompareResults.R (tolerance
# 1e-3 — cross-backend CUDA-vs-OpenMP, matching the historical
# run-dc-comparison precedent for CUDA comparisons; the full run itself
# is always CUDA since every full uses the campaign's GPU-distributed
# bin/dc). Only called where csv_ground_truth_backends(n) is non-empty.
# Prints "pass" or "fail"; degrades to "skipped" (not a hard failure) if
# the reference build/run itself cannot be completed — a broken reference
# path must not silently fail the whole full run's checkpoint, but must
# also not be misreported as a numeric pass.
run_ground_truth_check() {
  local topo=$1 n=$2 size_cli=$3 predicted_dc=$4 result_dir=$5
  local head; head=$(head_node)
  local gt_bin="$PROJECT_DIR/bin_openmp_gt/dc"

  if ! ssh_root "$head" "[ -x $gt_bin ]" 2>/dev/null; then
    # NOTE: warn (not log) deliberately — this function's stdout is
    # captured via $(...) by the caller (gt_verdict=$(run_ground_truth_
    # check ...)); log() writes to stdout and would corrupt that capture
    # (this exact bug was found empirically 2026-07-15, session real: a
    # ground-truth comparison that ACTUALLY PASSED was reported as failed
    # because the captured "verdict" was the whole multi-line log text,
    # not the bare "pass" token). Every diagnostic print inside this
    # function must go to stderr; only the final echo pass|fail|skipped
    # may touch stdout.
    warn "run_ground_truth_check($topo/N=$n): compilando bin_openmp_gt/dc (uma vez, isolado de bin/dc via BUILDDIR)"
    if ! ssh_root "$head" "
      source $NIX_PROFILE
      cd $PROJECT_DIR
      nix develop --command make BACKEND=openmp BUILDDIR=bin_openmp_gt
    " >"$result_dir/ground_truth_build.log" 2>&1; then
      warn "run_ground_truth_check($topo/N=$n): falha ao compilar referência OpenMP — ver $result_dir/ground_truth_build.log — PULANDO verificação (não conta como falha numérica)"
      echo skipped
      return 0
    fi
  fi

  local gt_dc="$result_dir/ground_truth.dc"
  if ! ssh_root "$head" "
    source $NIX_PROFILE
    cd $PROJECT_DIR
    nix develop --command mpirun --allow-run-as-root -np 1 $gt_bin \
      --size-x=$size_cli --size-y=$size_cli --size-z=$size_cli \
      --absorption=$ABSORPTION --dx=$DC_DX --dy=$DC_DY --dz=$DC_DZ \
      --dt=$DC_DT --time-max=$DC_TIME_MAX --output-file=$gt_dc
  " >"$result_dir/ground_truth_run.log" 2>&1; then
    warn "run_ground_truth_check($topo/N=$n): execução np=1 OpenMP falhou — ver $result_dir/ground_truth_run.log — PULANDO verificação"
    echo skipped
    return 0
  fi

  local verdict_out rc
  verdict_out=$(ssh_root "$head" "cd $PROJECT_DIR && Rscript validation/CompareResults.R 1e-3 $gt_dc $predicted_dc" 2>&1) && rc=0 || rc=$?
  echo "$verdict_out" > "$result_dir/ground_truth_compare.log"
  warn "run_ground_truth_check($topo/N=$n): $verdict_out"
  diary "Ground truth $topo/N=$n: $verdict_out"
  ssh_root "$head" "rm -f $gt_dc" 2>/dev/null || true

  if [ "$rc" -eq 0 ]; then echo pass; else echo fail; fi
}

# ---------------------------------------------------------------------
# FASE FULL — 1 execução por topologia (menor N), nativo, correção
# numérica onde fisicamente possível.
# ---------------------------------------------------------------------
run_full_phase() {
  log "=== FASE FULL (numérico, 1 execução/topologia, nativo) ==="
  if [ "$DRY_RUN" -eq 0 ]; then
    shape_off
  fi

  while IFS=$'\t' read -r topo nos gpus n vram; do
    [ -z "$topo" ] && continue

    exp_id="full_${topo}_N${n}"
    if [ -n "$ONLY_ID" ] && [ "$exp_id" != "$ONLY_ID" ]; then
      continue
    fi

    if [ "$nos" -gt "$AVAIL" ]; then
      warn "FULL $exp_id: precisa de $nos nó(s), só $AVAIL disponível(is) — DEFER (não persistido, retomado quando houver nós suficientes)"
      N_SKIPPED_DEFER=$((N_SKIPPED_DEFER + 1))
      continue
    fi

    if ! csv_row_fits_gpu_capacity "$nos" "$gpus"; then
      warn "FULL $exp_id: distribuição uniforme ($gpus GPUs / $nos nós) excede a capacidade real de algum nó (ver validate_gpu_policy) — DEFER"
      diary "FULL $exp_id adiado: capacidade real de GPU insuficiente em algum nó para a distribuição uniforme desta topologia."
      N_SKIPPED_DEFER=$((N_SKIPPED_DEFER + 1))
      continue
    fi

    local gt_backends; gt_backends=$(csv_ground_truth_backends "$n")

    if [ "$DRY_RUN" -eq 1 ]; then
      log "[dry-run] FULL $exp_id: nos=$nos gpus=$gpus N=$n ground_truth=${gt_backends:-<nenhum: reprodutibilidade apenas>}"
      continue
    fi

    local expected_dc_bytes; expected_dc_bytes=$(csv_expected_dc_bytes "$n")
    if ! validate_disk_space_for_full "$n"; then
      diary "FULL $exp_id adiado: espaço em disco insuficiente para .dc esperado (~$(awk -v b="$expected_dc_bytes" 'BEGIN{printf "%.1f", b/1e9}')GB)."
      N_SKIPPED_DEFER=$((N_SKIPPED_DEFER + 1))
      continue
    fi

    local size_cli; size_cli=$(csv_cli_size "$n")
    local hostfile="$STATE_DIR/.hostfile_${exp_id}"
    csv_build_experiment_hostfile "$nos" "$gpus" "$hostfile"

    local rep=1   # full is a single representative run, never repeated
    if ! checkpoint_should_run "$exp_id" "$rep" "$gpus" full "$expected_dc_bytes"; then
      N_SKIPPED_DONE=$((N_SKIPPED_DONE + 1))
      continue
    fi

    local remaining=""
    remaining=$(oar_walltime_remaining_s 2>/dev/null) || remaining=""
    if [ -n "$remaining" ] && [ "$remaining" -lt "$MIN_WALLTIME_MARGIN_S" ]; then
      warn "FULL $exp_id: DEFER — apenas ${remaining}s de walltime restante (< margem ${MIN_WALLTIME_MARGIN_S}s)"
      N_SKIPPED_DEFER=$((N_SKIPPED_DEFER + 1))
      continue
    fi

    local result_dir; result_dir=$(checkpoint_result_dir "$exp_id" "$rep")
    rm -rf "$result_dir"; mkdir -p "$result_dir"
    local out_dc="./validation/predicted_${exp_id}.dc"

    EXP_BANDA="native" EXP_NOS=$nos EXP_GPUS=$gpus EXP_TOPOLOGIA=$topo EXP_N=$n EXP_VRAM=$vram EXP_SIZE_CLI=$size_cli EXP_REP=$rep

    RUN_HOSTFILE=$hostfile RUN_NP=$gpus RUN_NATIVE=1 RUN_RESULT_DIR=$result_dir
    if [ -n "$remaining" ]; then
      RUN_TIMEOUT_S=$((remaining - MIN_WALLTIME_MARGIN_S))
    else
      RUN_TIMEOUT_S=0
    fi
    RUN_APP_ARGS=(--size-x="$size_cli" --size-y="$size_cli" --size-z="$size_cli" \
                   --absorption="$ABSORPTION" --dx="$DC_DX" --dy="$DC_DY" --dz="$DC_DZ" \
                   --dt="$DC_DT" --time-max="$DC_TIME_MAX" --output-file="$out_dc")

    log "--- FULL $exp_id (np=$RUN_NP, ground_truth=${gt_backends:-nenhum}) ---"
    orphan_cleanup
    inflight_mark "$exp_id" "$rep" full "$result_dir"
    local t0 rc=0; t0=$(date +%s)
    run_experiment || rc=$?
    EXP_ELAPSED_S=$(($(date +%s) - t0)); EXP_RC=$rc
    inflight_clear

    [ -f "$PROJECT_DIR/$out_dc" ] && mv -f "$PROJECT_DIR/$out_dc" "$result_dir/predicted.dc"
    sciencelog_write_metadata "$result_dir"

    local gt_verdict=""
    if [ "$rc" -eq 0 ] && [ -n "$gt_backends" ] && [ -f "$result_dir/predicted.dc" ]; then
      gt_verdict=$(run_ground_truth_check "$topo" "$n" "$size_cli" "$result_dir/predicted.dc" "$result_dir")
      [ "$gt_verdict" = skipped ] && gt_verdict=""   # skipped != fail; do not gate integrity on an unrunnable reference
    fi

    if [ "$rc" -eq 0 ] && checkpoint_integrity_ok "$result_dir" "$gpus" full "$expected_dc_bytes" "$gt_verdict"; then
      checkpoint_mark "$exp_id" "$rep" done "$result_dir" full
      sciencelog_diary_experiment "$exp_id" "$rep" done "$EXP_ELAPSED_S"
      N_RUN_OK=$((N_RUN_OK + 1))
      # Retencao "validar-e-descartar" (design doc secao 5.1/9): o .dc so
      # sobrevive ate aqui, apos passar pela checagem de integridade
      # (incluindo tamanho exato e, se aplicavel, o veredito de ground
      # truth) acima. Marcador .discarded permite que checkpoint_
      # integrity_ok reconheca este 'done' como legitimo em verificacoes
      # futuras sem exigir o .dc (ja intencionalmente descartado).
      : > "$result_dir/predicted.dc.discarded"
      rm -f "$result_dir/predicted.dc"
    else
      local status=failed
      [ "$rc" -eq 124 ] && status=timeout
      checkpoint_mark "$exp_id" "$rep" "$status" "$result_dir" full
      sciencelog_diary_experiment "$exp_id" "$rep" "$status" "$EXP_ELAPSED_S"
      warn "$exp_id FALHOU (rc=$rc, status=$status, ground_truth_verdict=${gt_verdict:-n/a})"
      N_RUN_FAILED=$((N_RUN_FAILED + 1))
      handle_run_failure "$rc" "$result_dir"
    fi
  done < <(csv_topology_representatives)
}

# ---------------------------------------------------------------------
# FASE BENCH — todas as (banda,topologia,N) x REPS_PER_EXPERIMENT,
# shaped, --skip-output.
# ---------------------------------------------------------------------
run_bench_phase() {
  log "=== FASE BENCH (timing/masking, --skip-output, shaped) ==="

  for banda in "${BANDWIDTHS[@]}"; do
    local rows_this_banda
    rows_this_banda=$(csv_each_compatible_row "$AVAIL" | awk -F'\t' -v b="$banda" -v only="$ONLY_ID" '
      $1==b {
        id="bench_"$1"_"$2"n_"$3"g_N"$5
        if (only == "" || id == only) print
      }' | wc -l)
    [ "$rows_this_banda" -eq 0 ] && continue

    log "--- Banda: $banda ($rows_this_banda linha(s) compatível(is)) ---"
    if [ "$DRY_RUN" -eq 0 ]; then
      shape_apply "$banda"
      validate_before_batch "$banda"
    fi

    while IFS=$'\t' read -r csv_banda csv_nos csv_gpus csv_topo csv_n csv_vram; do
      [ -z "$csv_banda" ] && continue
      exp_id="bench_${csv_banda}_${csv_nos}n_${csv_gpus}g_N${csv_n}"
      if [ -n "$ONLY_ID" ] && [ "$exp_id" != "$ONLY_ID" ]; then
        continue
      fi

      if ! csv_vram_ok "$csv_vram"; then
        warn "SKIP $exp_id: VRAM necessária (${csv_vram}GB) excede o orçamento seguro (${GPU_VRAM_GB}GB x ${VRAM_SAFETY_MARGIN}) — gate conservador mantido até confirmação empírica (design doc secao 4/6.5, smoke test #2)"
        diary "Pulado $exp_id: VRAM ${csv_vram}GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5)."
        N_SKIPPED_VRAM=$((N_SKIPPED_VRAM + 1))
        continue
      fi

      if ! csv_row_fits_gpu_capacity "$csv_nos" "$csv_gpus"; then
        warn "SKIP $exp_id: distribuição uniforme ($csv_gpus GPUs / $csv_nos nós) excede a capacidade real de algum nó — DEFER"
        diary "Pulado $exp_id: capacidade real de GPU insuficiente em algum nó para a distribuição uniforme desta linha."
        N_SKIPPED_DEFER=$((N_SKIPPED_DEFER + 1))
        continue
      fi

      local size_cli; size_cli=$(csv_cli_size "$csv_n")

      if [ "$DRY_RUN" -eq 1 ]; then
        log "[dry-run] BENCH $exp_id: nos=$csv_nos gpus=$csv_gpus topo=$csv_topo N=$csv_n size_cli=$size_cli x $REPS_PER_EXPERIMENT reps"
        continue
      fi

      local hostfile="$STATE_DIR/.hostfile_${exp_id}"
      csv_build_experiment_hostfile "$csv_nos" "$csv_gpus" "$hostfile"

      for rep in $(seq 1 "$REPS_PER_EXPERIMENT"); do
        EXP_BANDA=$csv_banda EXP_NOS=$csv_nos EXP_GPUS=$csv_gpus EXP_TOPOLOGIA=$csv_topo EXP_N=$csv_n EXP_VRAM=$csv_vram EXP_SIZE_CLI=$size_cli EXP_REP=$rep

        if ! checkpoint_should_run "$exp_id" "$rep" "$csv_gpus" bench; then
          N_SKIPPED_DONE=$((N_SKIPPED_DONE + 1))
          continue
        fi

        local remaining=""
        remaining=$(oar_walltime_remaining_s 2>/dev/null) || remaining=""
        if [ -n "$remaining" ] && [ "$remaining" -lt "$MIN_WALLTIME_MARGIN_S" ]; then
          warn "BENCH $exp_id rep$rep: DEFER — apenas ${remaining}s de walltime restante (< margem ${MIN_WALLTIME_MARGIN_S}s)"
          N_SKIPPED_DEFER=$((N_SKIPPED_DEFER + 1))
          continue
        fi

        local result_dir; result_dir=$(checkpoint_result_dir "$exp_id" "$rep")
        rm -rf "$result_dir"; mkdir -p "$result_dir"

        RUN_HOSTFILE=$hostfile RUN_NP=$csv_gpus RUN_NATIVE=0 RUN_RESULT_DIR=$result_dir
        if [ -n "$remaining" ]; then
          RUN_TIMEOUT_S=$((remaining - MIN_WALLTIME_MARGIN_S))
        else
          RUN_TIMEOUT_S=0
        fi
        RUN_APP_ARGS=(--size-x="$size_cli" --size-y="$size_cli" --size-z="$size_cli" \
                       --absorption="$ABSORPTION" --dx="$DC_DX" --dy="$DC_DY" --dz="$DC_DZ" \
                       --dt="$DC_DT" --time-max="$DC_TIME_MAX" --skip-output)

        log "--- BENCH $exp_id rep$rep/$REPS_PER_EXPERIMENT (np=$RUN_NP) ---"
        orphan_cleanup
        inflight_mark "$exp_id" "$rep" bench "$result_dir"
        local t0 rc=0; t0=$(date +%s)
        run_experiment || rc=$?
        EXP_ELAPSED_S=$(($(date +%s) - t0)); EXP_RC=$rc
        inflight_clear

        sciencelog_write_metadata "$result_dir"

        if [ "$rc" -eq 0 ] && checkpoint_integrity_ok "$result_dir" "$csv_gpus" bench; then
          checkpoint_mark "$exp_id" "$rep" done "$result_dir" bench
          sciencelog_diary_experiment "$exp_id" "$rep" done "$EXP_ELAPSED_S"
          N_RUN_OK=$((N_RUN_OK + 1))
        else
          local status=failed
          [ "$rc" -eq 124 ] && status=timeout
          checkpoint_mark "$exp_id" "$rep" "$status" "$result_dir" bench
          sciencelog_diary_experiment "$exp_id" "$rep" "$status" "$EXP_ELAPSED_S"
          warn "$exp_id rep$rep FALHOU (rc=$rc, status=$status) — ver $result_dir/dc.output"
          N_RUN_FAILED=$((N_RUN_FAILED + 1))
          handle_run_failure "$rc" "$result_dir"
        fi
      done
    done < <(csv_each_compatible_row "$AVAIL" | awk -F'\t' -v b="$banda" '$1==b')
  done

  if [ "$DRY_RUN" -eq 0 ]; then
    shape_off
  fi
}

case "$PHASE" in
  full)  run_full_phase ;;
  bench) run_bench_phase ;;
  all)   run_full_phase; run_bench_phase ;;
esac

log "=== Campanha (esta execução do orquestrador, fase=$PHASE) concluída ==="
log "  OK: $N_RUN_OK | Falhas: $N_RUN_FAILED | Pulados (já íntegros): $N_SKIPPED_DONE | Pulados (VRAM): $N_SKIPPED_VRAM | Adiados (nós/disco/walltime): $N_SKIPPED_DEFER"
log "  Status acumulado (todas as execuções do orquestrador até agora):"
checkpoint_summary
diary "Execução do orquestrador finalizada (fase=$PHASE): OK=$N_RUN_OK FAILED=$N_RUN_FAILED SKIPPED_DONE=$N_SKIPPED_DONE SKIPPED_VRAM=$N_SKIPPED_VRAM SKIPPED_DEFER=$N_SKIPPED_DEFER"

if [ "$N_RUN_FAILED" -gt 0 ]; then
  warn "Há $N_RUN_FAILED repetição(ões) com falha/timeout nesta execução — reexecute o orquestrador (ele tentará de novo automaticamente) ou inspecione os logs em $RESULTS_DIR."
  exit 1
fi
