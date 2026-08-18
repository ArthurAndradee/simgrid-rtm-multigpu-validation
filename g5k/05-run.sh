#!/usr/bin/env bash
# 05-run.sh — runs on the FRONTEND. Generates the MPI hostfile from the GPU
# census, computes np, launches Fletcher from the head node inside the Nix
# shell, converts Akypuera traces and archives everything under results/.
#
#   ./05-run.sh [options] -- <dc args...>
#
# Options:
#   --rpn <N|gpus>   ranks per node (default: gpus = one rank per GPU;
#                    use --rpn 1 to reproduce the SimGrid "1 rank per host"
#                    scenarios of the TCC)
#   --np <N>         override total ranks (default: sum of hostfile slots)
#   --native         do NOT force UCX_TLS=tcp (unshaped baseline; RDMA/RC
#                    allowed). Refuses to run if shaping is active.
#   --label <name>   tag for the results directory
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh
require_nodes_file
[ -s "$GPUS_FILE" ] || die "$GPUS_FILE missing — run 02-setup.sh"

RPN=gpus NP="" NATIVE=0 LABEL=run
while [ $# -gt 0 ]; do
  case $1 in
    --rpn)    RPN=$2; shift 2 ;;
    --np)     NP=$2; shift 2 ;;
    --native) NATIVE=1; shift ;;
    --label)  LABEL=$2; shift 2 ;;
    --) shift; break ;;
    *) die "unknown option $1" ;;
  esac
done
[ $# -gt 0 ] || die "no application arguments given (use: 05-run.sh [opts] -- <dc args>)"
APP_ARGS=("$@")

# ---- hostfile: slots = min(RPN, gpus(node)); chuc-7 (3 GPUs) never oversubscribed
awk -v rpn="$RPN" '{
  s = $2
  if (rpn != "gpus" && rpn + 0 < s) s = rpn + 0
  print $1 " slots=" s
}' "$GPUS_FILE" > "$HOSTFILE_MPI"
TOTAL=$(total_slots)
NP=${NP:-$TOTAL}
[ "$NP" -le "$TOTAL" ] || die "np=$NP exceeds available GPU slots ($TOTAL)"

if is_prime "$NP" && [ "$NP" -gt 3 ]; then
  log "WARNING: np=$NP is prime -> MPI_Dims_create will produce a {${NP},1,1}"
  log "         slices decomposition (worst case per the TCC, Sec. 5.3)."
  log "         Consider --np with a composite value (8, 12, 16, 27, ...)."
fi

# ---- shaping vs transport consistency
SHAPING=$(cat "$STATE_DIR/current_shaping.txt" 2>/dev/null || echo "off")
if [ "$NATIVE" -eq 1 ] && [ "$SHAPING" != "off" ]; then
  die "--native with active shaping ($SHAPING): RDMA bypasses tc; run ./04-shape.sh off first"
fi
if [ "$NATIVE" -eq 0 ]; then
  # 2026-07-09/10 on-hardware root-cause (chuc-6/7, job 2165552), CONFIRMED
  # by --mca pml_base_verbose 10 + UCX_LOG_LEVEL=debug:
  #
  #   This flake's OpenMPI (5.0.9) is built `--without-cuda` (opal_info
  #   confirms opal_built_with_cuda_support=false) — the earlier theory
  #   about CUDA-awareness/cuda_copy/cuda_ipc was WRONG. This UCX (1.19.0)
  #   build also has no cuda_copy/cuda_ipc compiled in at all (confirmed:
  #   "transports 'cuda_copy','cuda_ipc' are not available" warning), so
  #   listing them in UCX_TLS was a no-op at best.
  #
  #   The real cause: OMPI's pml_ucx component has its OWN transport
  #   allow-list, the MCA param `pml_ucx_tls` (synonym `opal_common_ucx_tls`),
  #   INDEPENDENT of the UCX_TLS env var. Its compiled-in default is
  #   "rc_verbs,ud_verbs,rc_mlx5,dc_mlx5,ud_mlx5,cuda_ipc,rocm_ipc" (verbs/
  #   IB only — see `ompi_info --all | grep pml_ucx_tls`). When UCX_TLS
  #   restricts UCX itself to tcp,self,sm, UCX's ucp_context still inits
  #   fine (confirmed in the debug log: "created ucp context ... 5 mds 5
  #   tls"), but pml_ucx then intersects that against its OWN default list,
  #   finds zero overlap, and mca_pml_ucx_component_init() fails silently
  #   -> generic OMPI error "No components were able to be opened in the
  #   pml framework". UCX_TLS alone was never going to fix this.
  #
  #   Fix, verified end-to-end on real hardware (2-node, 8-GPU, np=8,
  #   1gbit shaped): pass --mca pml_ucx_tls with the SAME list as UCX_TLS.
  UCX_ENV="export UCX_TLS=tcp,self,sm
export UCX_NET_DEVICES=$KAVLAN_IFACE"
  UCX_FWD="-x UCX_TLS -x UCX_NET_DEVICES"
  PML_UCX_TLS_MCA="--mca pml_ucx_tls tcp,self,sm"
else
  UCX_ENV=":"
  UCX_FWD=""
  PML_UCX_TLS_MCA=""
fi

HEAD=$(head_node)
TS=$(date +%Y%m%d-%H%M%S)
RESULT_DIR=$PROJECT_DIR/results/${TS}_${LABEL}_np${NP}
mkdir -p "$RESULT_DIR"

log "np=$NP over $(node_count) nodes (hostfile below); results -> $RESULT_DIR"
cat "$HOSTFILE_MPI" | tee "$RESULT_DIR/hostfile.mpi"

# ---- metadata for reproducibility
{
  echo "date: $TS"; echo "label: $LABEL"; echo "np: $NP"; echo "rpn: $RPN"
  echo "native: $NATIVE"; echo "shaping: $SHAPING"
  echo "args: ${APP_ARGS[*]}"
  echo "git: $(git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || echo n/a)"
} > "$RESULT_DIR/metadata.txt"
for h in $(nodes); do
  ssh_root "$h" "hostname; nvidia-smi -L; tc qdisc show dev $KAVLAN_IFACE" \
    >> "$RESULT_DIR/node_info.txt" 2>&1 || true
done

# ---- launch from the head node, inside the Nix shell
# Notes:
#  * root<->root ssh works via /root/.ssh/config (02-setup) -> no plm_rsh_args;
#  * identical /nix/store on all nodes -> mpirun's absolute-path daemon
#    launch (prted/orted) works without --prefix tricks;
#  * LD_LIBRARY_PATH gets nv-bridge APPENDED (not overwritten) and is forwarded;
#  * RST_BUFFER_SIZE is forwarded with -x (previously only rank 0 saw it);
#  * --map-by slot fills each node up to its slots= (4,4,...,3 with chuc-7),
#    keeping consecutive Cartesian ranks co-located -> neighbor traffic uses
#    shared memory; --bind-to numa keeps each rank inside one NUMA domain
#    without strangling it on a single core.
node_script "$HEAD" <<EOF
set -e
source $NIX_PROFILE
cd $PROJECT_DIR
rm -f rastro-*.rst dc.trace dc.csv
$UCX_ENV
export RST_BUFFER_SIZE=1073741824
export LD_LIBRARY_PATH=/tmp/nv-bridge:\${LD_LIBRARY_PATH:-}
nix develop --command bash -c '
  set -e
  export LD_LIBRARY_PATH=/tmp/nv-bridge:\$LD_LIBRARY_PATH
  mpirun --allow-run-as-root \\
    -np $NP \\
    --hostfile $HOSTFILE_MPI \\
    --map-by slot \\
    --bind-to numa \\
    --mca pml ucx $PML_UCX_TLS_MCA \\
    -x PATH -x LD_LIBRARY_PATH -x RST_BUFFER_SIZE $UCX_FWD \\
    ./bin/dc ${APP_ARGS[*]} 2>&1 | tee dc.output
  # trace post-processing inside the same shell (aky_converter, pj_dump)
  if ls rastro-*.rst >/dev/null 2>&1; then
    aky_converter rastro-*.rst > dc.trace
    pj_dump -z -l 9 dc.trace | grep ^State > dc.csv || true
  fi
'
EOF

# ---- archive (NFS: visible on frontend)
mv -f "$PROJECT_DIR"/rastro-*.rst "$RESULT_DIR"/ 2>/dev/null || true
for f in dc.trace dc.csv dc.output; do
  [ -f "$PROJECT_DIR/$f" ] && mv -f "$PROJECT_DIR/$f" "$RESULT_DIR/"
done
log "done. Results in $RESULT_DIR"
