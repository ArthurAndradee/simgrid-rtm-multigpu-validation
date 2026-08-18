# shellcheck shell=bash
# ---------------------------------------------------------------------------
# sciencelog.sh — rich, reproducibility-grade logging for each experiment,
# meant to be consumed directly when writing the TCC's methodology section.
# ---------------------------------------------------------------------------

: "${VERSIONS_FILE:=$LOGS_DIR/versions.txt}"

# sciencelog_capture_versions — captures toolchain versions ONCE per
# campaign (they don't change per experiment; capturing them ~500 times
# would just add redundant SSH round-trips). Referenced from every
# experiment's metadata.txt instead of re-queried each time.
sciencelog_capture_versions() {
  local head; head=$(head_node)
  log "capturing toolchain versions (once) from $head"
  node_script "$head" <<EOF > "$VERSIONS_FILE" 2>&1
source $NIX_PROFILE
cd $PROJECT_DIR
nix develop --command bash -c '
  echo "date_captured: \$(date -Iseconds)"
  echo "head_node: $head"
  echo "--- CUDA ---"
  nvcc --version 2>&1 | tail -5
  echo "--- OpenMPI ---"
  mpirun --version 2>&1 | head -3
  ompi_info --parsable 2>/dev/null | grep -E "^config:command_line|^config:cuda" || true
  echo "--- UCX ---"
  ucx_info -v 2>&1
  echo "--- Akypuera / Pajé ---"
  aky_converter -h 2>&1 | head -2 || true
  pj_dump --help 2>&1 | head -2 || true
'
EOF
  diary "Versões de toolchain capturadas em $VERSIONS_FILE"
}

# sciencelog_write_metadata <result_dir> — writes a rich metadata.txt for
# one experiment repetition. Expects the following variables to already be
# set by the caller (the orchestrator loop): EXP_BANDA EXP_NOS EXP_GPUS
# EXP_TOPOLOGIA EXP_N EXP_SIZE_CLI EXP_REP RUN_NP RUN_NATIVE RUN_HOSTFILE
# EXP_ELAPSED_S EXP_RC DC_BINARY_SHA256.
sciencelog_write_metadata() {
  local dir=$1
  local scripts_hash
  scripts_hash=$(find "$G5K_DIR/lib" "$G5K_DIR/scripts" -type f -name '*.sh' -exec sha256sum {} \; | sort | sha256sum | awk '{print $1}')

  {
    echo "# Metadata do experimento — gerado automaticamente"
    echo "timestamp: $(date -Iseconds)"
    echo "experiment_id: $(csv_experiment_id "$EXP_BANDA" "$EXP_NOS" "$EXP_GPUS" "$EXP_N")"
    echo "repeticao: $EXP_REP / $REPS_PER_EXPERIMENT"
    echo ""
    echo "## Parâmetros do experimento (do CSV, não recalculados)"
    echo "banda_rede: $EXP_BANDA"
    echo "num_nos_csv: $EXP_NOS"
    echo "num_gpus_csv: $EXP_GPUS"
    echo "topologia_mpi_csv: $EXP_TOPOLOGIA"
    echo "tamanho_global_n: $EXP_N"
    echo "vram_gb_por_gpu_csv: ${EXP_VRAM:-n/a}"
    echo ""
    echo "## Conversão para CLI (STENCIL=$STENCIL, ABSORPTION=$ABSORPTION)"
    echo "size_x=size_y=size_z: $EXP_SIZE_CLI"
    echo "formula: size_cli = Tamanho_Global_N - 2*STENCIL - 2*ABSORPTION"
    echo ""
    echo "## Execução real"
    echo "np: $RUN_NP"
    echo "native_mode: $RUN_NATIVE"
    echo "shaping_atual: $(current_shaping)"
    echo "hostfile:"
    sed 's/^/  /' "$RUN_HOSTFILE"
    echo "map_by: $MPI_MAP_BY"
    echo "bind_to: $MPI_BIND_TO"
    echo "pml: ucx"
    echo "mca_pml_ucx_tls: $([ "$RUN_NATIVE" -eq 0 ] && echo 'tcp,self,sm (validated fix, see lib/run.sh header)' || echo 'unset (native/RDMA path)')"
    echo "return_code: ${EXP_RC:-n/a}"
    echo "elapsed_wallclock_seconds: ${EXP_ELAPSED_S:-n/a}"
    echo ""
    echo "## Ambiente / hardware"
    for h in $(nodes | head -n "$EXP_NOS"); do
      echo "node: $h"
      ssh_root "$h" "hostname; nvidia-smi -L; nvidia-smi --query-gpu=index,utilization.gpu,memory.used,memory.total --format=csv,noheader" 2>&1 | sed 's/^/  /'
      ssh_root "$h" "tc qdisc show dev $KAVLAN_IFACE" 2>&1 | sed 's/^/  tc: /'
    done
    echo ""
    echo "## Reprodutibilidade"
    echo "git_commit: $(git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || echo n/a)"
    echo "scripts_sha256_combined: $scripts_hash"
    echo "dc_binary_sha256: ${DC_BINARY_SHA256:-n/a}"
    echo "versions_file: $VERSIONS_FILE (capturado uma vez por campanha, ver esse arquivo)"
  } > "$dir/metadata.txt"
}

# sciencelog_diary_experiment — one-line diary entry per finished repetition.
sciencelog_diary_experiment() {
  local id=$1 rep=$2 status=$3 elapsed=$4
  diary "Experimento $id rep$rep -> $status (${elapsed}s)"
}
