# shellcheck shell=bash
# ---------------------------------------------------------------------------
# setup.sh — SSH mesh, dynamic GPU census, Nix, nv-bridge, warmup. Factored
# out of the validated g5k/02-setup.sh (unchanged behavior).
#
# NOTE on GPU policy: this file only DISCOVERS GPUs (nvidia-smi, never
# hardcoded). Whether "N GPUs" is acceptable for the campaign is a decision
# made by lib/validate.sh (validate_gpu_policy), not here — keeps discovery
# generic/reusable and the strict "must be exactly 4" campaign rule isolated
# and easy to audit/relax later.
# ---------------------------------------------------------------------------

# setup_ssh_mesh — root<->root SSH across all nodes (needed for mpirun to
# spawn daemons on every node, not just node1->node2).
setup_ssh_mesh() {
  log "SSH mesh across $(node_count) nodes"
  if [ ! -f "$CLUSTER_KEY" ]; then
    ssh-keygen -q -t ed25519 -N "" -C "g5k-cluster-key" -f "$CLUSTER_KEY"
  fi
  local pub; pub=$(cat "$CLUSTER_KEY.pub")
  local h
  for h in $(nodes); do
    scp "${SSH_OPTS[@]}" -q "$CLUSTER_KEY" "root@$h:/root/.ssh/id_cluster"
  done
  all_nodes_script "
    set -e
    chmod 600 /root/.ssh/id_cluster
    grep -qF '$pub' /root/.ssh/authorized_keys 2>/dev/null \
      || echo '$pub' >> /root/.ssh/authorized_keys
    cat > /root/.ssh/config <<'CFG'
Host *
  IdentityFile /root/.ssh/id_cluster
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
CFG
    chmod 600 /root/.ssh/config
  "
  local head; head=$(head_node)
  for h in $(nodes); do
    ssh_root "$head" "ssh root@$h true" \
      || die "root@$head cannot ssh root@$h — MPI daemon launch would fail"
  done
}

# gpu_census — nvidia-smi census on every node -> $GPUS_FILE + full-census
# $HOSTFILE_MPI. Purely descriptive; never hardcodes a GPU count.
gpu_census() {
  log "GPU census (nvidia-smi, no hardcoded assumptions)"
  : > "$GPUS_FILE"
  local h n
  for h in $(nodes); do
    n=$(ssh_root "$h" "nvidia-smi --query-gpu=index --format=csv,noheader | wc -l") \
      || die "nvidia-smi failed on $h — is the NVIDIA driver in $DEPLOY_ENV?"
    [ "$n" -ge 1 ] || die "$h reports 0 GPUs"
    echo "$h $n" >> "$GPUS_FILE"
    log "  $h: $n GPU(s)"
  done
  awk '{print $1" slots="$2}' "$GPUS_FILE" > "$HOSTFILE_MPI"
  log "  full-census hostfile: $HOSTFILE_MPI (total slots: $(total_slots))"
}

# setup_nix_and_bridge — Nix (store bind-mounted on /tmp) + nv-bridge
# (host NVIDIA driver libs exposed to the Nix toolchain) on every node.
setup_nix_and_bridge() {
  log "Nix (store on /tmp) + nv-bridge on every node (parallel)"
  all_nodes_script '
    set -e
    if [ ! -e /nix/var/nix/profiles/default ]; then
      mkdir -p /tmp/nix /nix
      mountpoint -q /nix || mount --bind /tmp/nix /nix
      sh <(curl -fsSL https://nixos.org/nix/install) --daemon --yes
    fi
    mkdir -p /root/.config/nix
    echo "experimental-features = nix-command flakes" > /root/.config/nix/nix.conf
    git config --global --add safe.directory "*"

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
}

# setup_nix_warmup — `nix develop` on every node, WAITED ON (identical
# store paths on all nodes are a hard requirement: mpirun launches remote
# daemons by absolute /nix/store path).
setup_nix_warmup() {
  log "nix develop warm-up on ALL nodes (parallel, waited on)"
  all_nodes_script "
    set -e
    source $NIX_PROFILE
    cd $PROJECT_DIR
    nix develop --command true
  "
}

# setup_apt_deps — OS packages needed by lib/validate.sh's
# validate_bandwidth_effective (iperf3, jq) that are NOT part of the
# debiannvopen11-big base image — confirmed empirically 2026-07-17 (job
# 2169626): iperf3 absent, jq already present but installed anyway for
# robustness against a future base-image change. Best-effort per node
# (apt failures here shouldn't abort the whole campaign — validate.sh's
# own die() is the real gate if the tools end up genuinely missing).
setup_apt_deps() {
  log "installing iperf3/jq on all nodes (apt, best-effort)"
  all_nodes_script "
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y iperf3 jq >/dev/null 2>&1 || true
  "
}

# setup_run — full sequence, in order (matches g5k/02-setup.sh 1..5).
setup_run() {
  require_nodes_file
  setup_ssh_mesh
  gpu_census
  setup_apt_deps
  setup_nix_and_bridge
  setup_nix_warmup
  diary "Setup concluído. Censo de GPU: $(paste -sd', ' "$GPUS_FILE")"
}
