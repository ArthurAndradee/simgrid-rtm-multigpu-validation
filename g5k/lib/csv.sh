# shellcheck shell=bash
# ---------------------------------------------------------------------------
# csv.sh — consumes experiments.csv as the single source of truth. NEVER
# recomputes Num_Nos / Num_GPUs / Topologia_MPI / VRAM_GB_por_GPU /
# Dimensao_Local_Pior_Caso — those are read as-is. The only derived value
# computed here is the --size-x/y/z CLI conversion from Tamanho_Global_N,
# using the formula confirmed against src/main.c + src/coordinator.c +
# include/definitions.h (see conf/defaults.conf header comment).
#
# CSV columns (header, exact order):
#   Banda_Rede,Num_Nos,Num_GPUs,Topologia_MPI,Tamanho_Global_N,
#   Dimensao_Local_Pior_Caso,VRAM_GB_por_GPU
# ---------------------------------------------------------------------------

: "${EXPERIMENTS_CSV:=$CSV_DIR/experimentos.csv}"

# csv_selfcheck — guards against ABSORPTION/STENCIL drift silently producing
# wrong --size-x/y/z. Cross-checks the CLI-size formula against the one row
# manually verified against the real source code on 2026-07-10
# (N=64, 1 node/4 GPUs -> global size must reconstruct to 64).
csv_selfcheck() {
  local n=64
  local size_cli=$(( n - 2*STENCIL - 2*ABSORPTION ))
  local reconstructed=$(( size_cli + 2*ABSORPTION + 2*STENCIL ))
  [ "$reconstructed" -eq "$n" ] || die "csv_selfcheck: formula inconsistency (STENCIL=$STENCIL ABSORPTION=$ABSORPTION) — got $reconstructed, expected $n"
  [ -s "$EXPERIMENTS_CSV" ] || die "csv_selfcheck: $EXPERIMENTS_CSV missing/empty"
  local header; header=$(head -n1 "$EXPERIMENTS_CSV")
  case "$header" in
    Banda_Rede,Num_Nos,Num_GPUs,Topologia_MPI,Tamanho_Global_N,Dimensao_Local_Pior_Caso,VRAM_GB_por_GPU) ;;
    *) die "csv_selfcheck: unexpected CSV header: $header" ;;
  esac
}

# csv_cli_size <Tamanho_Global_N> — echoes the value for --size-x/y/z
# (domain is cubic in this CSV: same value used for x, y and z).
csv_cli_size() {
  local n=$1
  local s=$(( n - 2*STENCIL - 2*ABSORPTION ))
  [ "$s" -gt 0 ] || die "csv_cli_size: N=$n too small for STENCIL=$STENCIL ABSORPTION=$ABSORPTION (got $s)"
  echo "$s"
}

# csv_experiment_id <banda> <nos> <gpus> <N> — deterministic label used for
# results/ subdirectories and the checkpoint file. Does not embed the
# topology string (redundant with nos+gpus+N given a fixed CSV generator).
csv_experiment_id() {
  local banda=$1 nos=$2 gpus=$3 n=$4
  echo "${banda}_${nos}n_${gpus}g_N${n}"
}

# csv_vram_ok <vram_gb_por_gpu> — compares the CSV's precomputed worst-case
# per-GPU VRAM requirement against real hardware (GPU_VRAM_GB) with a safety
# margin. Never recomputes the requirement itself.
csv_vram_ok() {
  local need=$1
  awk -v need="$need" -v total="$GPU_VRAM_GB" -v margin="$VRAM_SAFETY_MARGIN" \
    'BEGIN { exit !(need <= total*margin) }'
}

# csv_gpu_distribution <nos> <gpus> — echoes "<n_gpus_on_node_1> ... <n_gpus_on_node_nos>"
# using fair round-robin (largest-remainder): first `gpus % nos` nodes get
# ceil(gpus/nos), the rest get floor(gpus/nos). Deterministic, order-stable.
# Does NOT decide correctness of MPI decomposition (that's MPI_Dims_create's
# job, driven purely by the total rank count) — only network locality.
csv_gpu_distribution() {
  local nos=$1 gpus=$2
  local base=$(( gpus / nos )) extra=$(( gpus % nos ))
  local i out=()
  for ((i = 0; i < nos; i++)); do
    if [ "$i" -lt "$extra" ]; then out+=($((base + 1))); else out+=("$base"); fi
  done
  echo "${out[@]}"
}

# csv_row_fits_gpu_capacity <nos> <gpus> — true iff csv_gpu_distribution's
# per-node share for the FIRST <nos> nodes (deterministic order from
# nodes()) does NOT exceed any of those nodes' REAL detected GPU count
# ($GPUS_FILE). MUST be called before csv_build_experiment_hostfile for
# every row; if false, the row must be DEFERRED, never silently attempted.
#
# [EMP, discovered 2026-07-15 on the real allocation]: chuc-3 reported
# 3/4 GPUs (GSP firmware fault on the 4th, confirmed against the G5K
# reference API — chuc-3 is documented with 4 identical A100s, so this is
# a real fault, not a documented hardware difference). Without this
# check, csv_build_experiment_hostfile's defensive want>have cap would
# silently reduce the TOTAL hostfile slots below Num_GPUs for any row
# touching that node — RUN_NP (from the CSV) would then exceed the
# hostfile's real total, and worse, if the orchestrator "fixed" RUN_NP to
# match the reduced total instead, MPI_Dims_create(reduced_total,...)
# would produce a DIFFERENT decomposition shape than the CSV's declared
# Topologia_MPI (e.g. 11 is prime -> a degenerate 1x1x11 slice, not the
# declared 2x2x3) — a silent, undetectable corruption of the
# topology/N mapping in the collected data. This check turns that failure
# mode into an explicit, logged DEFER instead.
csv_row_fits_gpu_capacity() {
  local nos=$1 gpus=$2
  local -a selected_nodes dist
  mapfile -t selected_nodes < <(nodes | head -n "$nos")
  [ "${#selected_nodes[@]}" -eq "$nos" ] || return 1
  read -ra dist <<< "$(csv_gpu_distribution "$nos" "$gpus")"
  local i host want have
  for i in "${!selected_nodes[@]}"; do
    host=${selected_nodes[$i]}
    want=${dist[$i]}
    have=$(awk -v h="$host" '$1==h{print $2}' "$GPUS_FILE")
    [ -n "$have" ] || return 1
    [ "$want" -le "$have" ] || return 1
  done
  return 0
}

# csv_build_experiment_hostfile <nos> <gpus> <out_file> — writes a
# "<host> slots=<n>" file for exactly this experiment: the first <nos> nodes
# (deterministic order from $NODES_FILE), with per-node slots from
# csv_gpu_distribution, defensively capped at each node's ACTUAL detected
# GPU count ($GPUS_FILE) — should never trigger the cap given the campaign's
# strict "exactly EXPECTED_GPUS_PER_NODE per node" validation gate, but a
# silent-overcommit bug here would be far worse than a defensive floor.
csv_build_experiment_hostfile() {
  local nos=$1 gpus=$2 out=$3
  local -a selected_nodes
  mapfile -t selected_nodes < <(nodes | head -n "$nos")
  [ "${#selected_nodes[@]}" -eq "$nos" ] || die "csv_build_experiment_hostfile: only ${#selected_nodes[@]}/$nos nodes available"

  local -a dist; read -ra dist <<< "$(csv_gpu_distribution "$nos" "$gpus")"

  : > "$out"
  local i host want have
  for i in "${!selected_nodes[@]}"; do
    host=${selected_nodes[$i]}
    want=${dist[$i]}
    have=$(awk -v h="$host" '$1==h{print $2}' "$GPUS_FILE")
    if [ "$want" -gt "$have" ]; then
      warn "csv_build_experiment_hostfile: $host wants $want GPUs but only $have detected — capping (should not happen if GPU policy validation passed)"
      want=$have
    fi
    echo "$host slots=$want" >> "$out"
  done
}

# csv_each_compatible_row <available_node_count> — prints one TSV line per
# CSV row whose Num_Nos <= available_node_count, in file order:
#   banda  nos  gpus  topologia  N  vram_por_gpu
csv_each_compatible_row() {
  local avail=$1
  awk -F, -v avail="$avail" '
    NR==1 { next }
    ($2+0) <= avail { printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1,$2,$3,$4,$5,$7 }
  ' "$EXPERIMENTS_CSV"
}

# csv_count_rows / csv_count_compatible_rows — for campaign-start reporting.
csv_count_rows() { tail -n +2 "$EXPERIMENTS_CSV" | grep -c . ; }
csv_count_compatible_rows() { csv_each_compatible_row "$1" | grep -c . ; }

# ---------------------------------------------------------------------------
# Topology-representative selection (campaign premise fixed 2026-07-14): 1
# FULL run per distinct MPI decomposition (Topologia_MPI), always at that
# topology's SMALLEST Tamanho_Global_N — not per CSV row. Confirmed from the
# real CSV that there are 10 distinct topologies (not 35 independent
# configs), each swept across a range of N (weak-scaling design) with the
# SAME Num_Nos/Num_GPUs/VRAM_GB_por_GPU across all 3 bandwidth duplicates of
# a given (topology,N) pair — so the representative selection is
# bandwidth-independent (matches: full runs go NATIVE, never shaped, per
# design doc 5.0 — the .dc result does not depend on bandwidth at all).
# ---------------------------------------------------------------------------

# csv_topology_representatives — one TSV line per distinct Topologia_MPI,
# at its smallest Tamanho_Global_N (the "1 full per topology" premise):
#   topologia  nos  gpus  N  vram_por_gpu
# Sorted by N for deterministic, human-readable output.
csv_topology_representatives() {
  awk -F, '
    NR==1 { next }
    {
      t=$4; n=$5+0
      if (!(t in minN) || n < minN[t]) { minN[t]=n; nos[t]=$2; gpus[t]=$3; vram[t]=$7 }
    }
    END { for (t in minN) printf "%s\t%s\t%s\t%s\t%s\n", t, nos[t], gpus[t], minN[t], vram[t] }
  ' "$EXPERIMENTS_CSV" | sort -k4,4n
}

# csv_is_topology_representative <topologia> <N> — true iff N is that
# topology's smallest N (i.e. this row is the one full/ground-truth
# candidate; all other N/bandwidth/rep combinations for this topology are
# bench-only per the fixed campaign premise).
csv_is_topology_representative() {
  local topologia=$1 n=$2
  local rep_n
  rep_n=$(csv_topology_representatives | awk -F'\t' -v t="$topologia" '$1==t{print $4}')
  [ -n "$rep_n" ] && [ "$rep_n" -eq "$n" ]
}

# csv_expected_dc_bytes <N> — exact expected size of a FULL run's
# --output-file, derived from coordinator.c's write loop (writes
# DC_OUTPUT_FIELDS floats of DC_FLOAT_BYTES bytes each, per GLOBAL index).
# [EMP] validated 2026-07-15 against two real files: N=28 test run ->
# 175616 bytes == 28^3*2*4 exactly; N=1536 real campaign file (session
# 2026-07-10) -> 28991029248 bytes == 1536^3*2*4 exactly. Used by both the
# disk preflight (validate_disk_space_for_full) and the full-run integrity
# check (checkpoint_integrity_ok) — one formula, no duplicated logic.
csv_expected_dc_bytes() {
  local n=$1
  awk -v n="$n" -v fields="$DC_OUTPUT_FIELDS" -v fbytes="$DC_FLOAT_BYTES" \
    'BEGIN { printf "%.0f\n", n*n*n*fields*fbytes }'
}

# csv_ground_truth_backends <N> — echoes a space-separated list of backends
# ("cuda", "openmp") for which an np=1 (single-process, local==global)
# ground-truth run physically fits within the safety-margined VRAM/RAM
# budget. Empty output means NO independent ground truth is possible at
# this N (per design doc 5.1-bis/5.0-quater: this is a hard physical limit
# of np=1 execution, N^3 growth of memory footprint — not a policy choice).
# Deliberately a live formula (not a hardcoded per-topology table) so it
# stays correct if the CSV's N values ever change.
csv_ground_truth_backends() {
  local n=$1
  local out=""
  awk -v n="$n" -v arrays="$DC_NP1_CUDA_ARRAYS" -v fbytes="$DC_FLOAT_BYTES" \
      -v total="$GPU_VRAM_GB" -v margin="$VRAM_SAFETY_MARGIN" \
    'BEGIN { need = n*n*n*arrays*fbytes; exit !(need <= total*1e9*margin) }' \
    && out="cuda"
  awk -v n="$n" -v arrays="$DC_NP1_OPENMP_ARRAYS" -v fbytes="$DC_FLOAT_BYTES" \
      -v total="$HOST_RAM_GB" -v margin="$RAM_SAFETY_MARGIN" \
    'BEGIN { need = n*n*n*arrays*fbytes; exit !(need <= total*1e9*margin) }' \
    && out="${out:+$out }openmp"
  echo "$out"
}
