#!/usr/bin/env bash
# 02-setup.sh — runs on the FRONTEND. For ANY number of nodes, in parallel:
#   1. root<->root SSH mesh (needed by mpirun to spawn daemons on all nodes)
#   2. GPU census  -> gpus.txt + hostfile.mpi  (chuc-7 with 3 GPUs handled here)
#   3. Nix install with /nix bind-mounted onto /tmp (big local partition)
#   4. nv-bridge (host NVIDIA driver libs exposed to the Nix toolchain)
#   5. `nix develop` warm-up on every node, WAITED ON (identical store paths
#      on all nodes are a hard requirement: mpirun launches remote daemons by
#      absolute /nix/store path).
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh
require_nodes_file

# ---------------------------------------------------------------- 1. SSH mesh
log "1/5 root<->root SSH mesh across $(node_count) nodes"
if [ ! -f "$CLUSTER_KEY" ]; then
  ssh-keygen -q -t ed25519 -N "" -C "g5k-cluster-key" -f "$CLUSTER_KEY"
fi
PUB=$(cat "$CLUSTER_KEY.pub")
for h in $(nodes); do
  scp "${SSH_OPTS[@]}" -q "$CLUSTER_KEY" "root@$h:/root/.ssh/id_cluster"
done
all_nodes_script "
  set -e
  chmod 600 /root/.ssh/id_cluster
  grep -qF '$PUB' /root/.ssh/authorized_keys 2>/dev/null \
    || echo '$PUB' >> /root/.ssh/authorized_keys
  cat > /root/.ssh/config <<'CFG'
Host *
  IdentityFile /root/.ssh/id_cluster
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
CFG
  chmod 600 /root/.ssh/config
"
# sanity: head node must reach every other node as root
HEAD=$(head_node)
for h in $(nodes); do
  ssh_root "$HEAD" "ssh root@$h true" \
    || die "root@$HEAD cannot ssh root@$h — MPI daemon launch would fail"
done

# --------------------------------------------------------------- 2. GPU census
log "2/5 GPU census (never assume 4 GPUs per node)"
: > "$GPUS_FILE"
for h in $(nodes); do
  n=$(ssh_root "$h" "nvidia-smi --query-gpu=index --format=csv,noheader | wc -l") \
    || die "nvidia-smi failed on $h — is the NVIDIA driver in $DEPLOY_ENV?"
  [ "$n" -ge 1 ] || die "$h reports 0 GPUs"
  echo "$h $n" >> "$GPUS_FILE"
  log "  $h: $n GPU(s)"
done
awk '{print $1" slots="$2}' "$GPUS_FILE" > "$HOSTFILE_MPI"
log "  hostfile: $HOSTFILE_MPI (total slots: $(total_slots))"

# ------------------------------------------------------- 3+4. Nix + nv-bridge
log "3/5+4/5 Nix (store on /tmp) + nv-bridge on every node (parallel)"
all_nodes_script '
  set -e
  # Relocate /nix BEFORE installing: /tmp sits on the large local partition
  # of kadeploy environments, / is small. Idempotent across re-runs.
  if [ ! -e /nix/var/nix/profiles/default ]; then
    mkdir -p /tmp/nix /nix
    mountpoint -q /nix || mount --bind /tmp/nix /nix
    sh <(curl -fsSL https://nixos.org/nix/install) --daemon --yes
  fi
  mkdir -p /root/.config/nix
  echo "experimental-features = nix-command flakes" > /root/.config/nix/nix.conf
  git config --global --add safe.directory "*"

  # nv-bridge: host driver userspace libs (libcuda & PTX JIT) for the
  # Nix-built binary. Created on EVERY node, not only node1/node2.
  mkdir -p /tmp/nv-bridge
  for d in /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib; do
    if ls "$d"/libcuda.so* >/dev/null 2>&1; then
      ln -sf "$d"/libcuda.so* /tmp/nv-bridge/
      ln -sf "$d"/libnvidia-ptxjitcompiler.so* /tmp/nv-bridge/ 2>/dev/null || true
      break
    fi
  done
  ls /tmp/nv-bridge/libcuda.so.1 >/dev/null
'

# ------------------------------------------------------------------ 5. warmup
log "5/5 nix develop warm-up on ALL nodes (parallel, waited on)"
all_nodes_script "
  set -e
  source $NIX_PROFILE
  cd $PROJECT_DIR
  nix develop --command true
"

log "setup OK. Next: ./03-build.sh"
