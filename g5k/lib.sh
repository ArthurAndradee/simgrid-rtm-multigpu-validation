# shellcheck shell=bash
# ---------------------------------------------------------------------------
# lib.sh — shared helpers for the Grid'5000 (chuc) experiment pipeline.
#
# Every script sources this file. All node-related logic is driven by
# $NODES_FILE / $GPUS_FILE; nothing is ever hardcoded for 2 nodes.
#
# Orchestration model:
#   * scripts 01..06 run on the SITE FRONTEND as the regular user;
#   * they reach the deployed nodes as root over SSH (kadeploy installed
#     the user's public key in root's authorized_keys);
#   * a dedicated "cluster key" is generated and pushed to /root/.ssh on
#     every node so that root@nodeA -> root@nodeB works for ALL pairs
#     (required by mpirun/PRRTE daemon launch, not just node1->node2).
# ---------------------------------------------------------------------------

: "${G5K_USER:=$USER}"
: "${G5K_HOME:=/home/$G5K_USER}"
: "${PROJECT_DIR:=$G5K_HOME/ic/io-research/distributed-cube-average}"
: "${STATE_DIR:=$PROJECT_DIR/g5k/state}"

: "${NODES_FILE:=$STATE_DIR/nodes.txt}"        # one primary hostname per line
: "${GPUS_FILE:=$STATE_DIR/gpus.txt}"          # "<host> <ngpus>" per line
: "${HOSTFILE_MPI:=$STATE_DIR/hostfile.mpi}"   # "<host> slots=<n>"

: "${DEPLOY_ENV:=debiannvopen11-big}"           # verified against `kaenv3 -l` on 2026-07-09 (site: lille).
                                                # "debian11-x64-big" does NOT exist on this site, and plain
                                                # "debian11-big" ships NO NVIDIA driver at all (nvidia-smi
                                                # would fail in 02-setup.sh). debiannvopen11-big is the
                                                # public G5K image with NVIDIA open kernel modules preinstalled,
                                                # suitable for Ampere/A100.
: "${KAVLAN_IFACE:=ens15f1np1}"                # physical NIC moved into the kavlan
: "${KAVLAN_DNS_SUFFIX:=eth1}"                 # G5K DNS alias for that NIC
: "${CLUSTER_KEY:=$STATE_DIR/cluster_key}"     # root<->root key, job-scoped

NIX_PROFILE=/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
          -o ConnectTimeout=20 -o BatchMode=yes -o LogLevel=ERROR)

log() { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

nodes()      { grep -v '^[[:space:]]*$' "$NODES_FILE"; }
node_count() { nodes | wc -l; }
head_node()  { nodes | head -n 1; }

require_nodes_file() {
  [ -s "$NODES_FILE" ] || die "$NODES_FILE missing/empty — run 01-deploy.sh first"
}

# ssh_root <host> [cmd...] — frontend user -> root@node (kadeploy key).
ssh_root() {
  local host=$1; shift
  ssh "${SSH_OPTS[@]}" "root@$host" "$@"
}

# node_script <host> <<'EOF' ... EOF — run a bash script (stdin) on one node.
node_script() {
  local host=$1
  ssh "${SSH_OPTS[@]}" "root@$host" 'bash -s'
}

# all_nodes_script "<bash script>" — run the same script on EVERY node in
# parallel, wait for all, fail (with the offending node's log) if any fails.
all_nodes_script() {
  local script=$1 rc=0
  local pids=() hosts=()
  mkdir -p "$STATE_DIR"
  while read -r h; do
    printf '%s' "$script" | node_script "$h" >"$STATE_DIR/.log.$h.$$" 2>&1 &
    pids+=("$!"); hosts+=("$h")
  done < <(nodes)
  local i
  for i in "${!pids[@]}"; do
    if ! wait "${pids[$i]}"; then
      rc=1
      echo "---------- FAILED on ${hosts[$i]} ----------" >&2
      cat "$STATE_DIR/.log.${hosts[$i]}.$$" >&2
    fi
  done
  rm -f "$STATE_DIR"/.log.*."$$"
  return "$rc"
}

# is_prime <n> — used to warn about MPI_Dims_create degenerating into slices.
is_prime() {
  local n=$1 i
  [ "$n" -lt 4 ] && return 0
  for ((i = 2; i * i <= n; i++)); do
    ((n % i == 0)) && return 1
  done
  return 0
}

# total_slots — sum of slots in $HOSTFILE_MPI
total_slots() {
  awk -F'slots=' '{s += $2} END {print s+0}' "$HOSTFILE_MPI"
}
