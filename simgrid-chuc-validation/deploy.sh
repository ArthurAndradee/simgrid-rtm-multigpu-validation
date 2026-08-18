#!/usr/bin/env bash
# deploy.sh — standalone kadeploy for the Option C validation job. NOT a
# wrapper around g5k/lib/deploy.sh: that function also configures kavlan
# (our reservation has none -- SMPI needs no real inter-node network, all
# ranks run in one process on one machine) and writes into g5k/state/
# (nodes.txt, kavlan_ips.txt, current_shaping.txt), which is the real
# campaign's shared state -- reusing it here would risk exactly the
# cross-contamination the user asked to avoid. Everything this script
# touches lives under simgrid-chuc-validation/state/ instead.
#
# Usage: from the frontend, inside the OAR job (OAR_JOB_ID and
# OAR_NODE_FILE set by the interactive/passive job environment):
#   cd ~/ic/io-research/distributed-cube-average
#   ./simgrid-chuc-validation/deploy.sh
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$DIR/state"
mkdir -p "$STATE_DIR"

: "${OAR_NODE_FILE:?run inside an OAR job (oarsub ... -t deploy)}"
: "${OAR_JOB_ID:?export OAR_JOB_ID explicitly}"
DEPLOY_ENV="debiannvopen11-big" # same image the real campaign uses (verified `kaenv3 -l`, site Lille)

sort -u -V "$OAR_NODE_FILE" > "$STATE_DIR/nodes.txt"
echo "Nodes for this job: $(paste -sd' ' "$STATE_DIR/nodes.txt")"

echo "=== kadeploy3: $DEPLOY_ENV on all nodes ==="
kadeploy3 -f "$STATE_DIR/nodes.txt" -e "$DEPLOY_ENV" -k "$HOME/.ssh/id_rsa.pub"

echo "=== Verifying SSH as root on every node ==="
# ssh -n (or </dev/null): without it, ssh inherits the while-loop's stdin
# (the nodes.txt file itself), and since ssh connects the remote command's
# stdin to that fd by default, it consumes the loop's remaining lines --
# every node after the first silently never gets checked. [EMP] found
# 2026-08-12, job 2186228: chuc-7 never printed a line here even though the
# deploy itself succeeded on both nodes.
while read -r h; do
  ssh -n -o BatchMode=yes -o StrictHostKeyChecking=no "root@$h" true \
    && echo "  $h: OK" \
    || echo "  $h: SSH FAILED — investigate before proceeding"
done < "$STATE_DIR/nodes.txt"

echo ""
echo "=== Done. Nodes: $(paste -sd', ' "$STATE_DIR/nodes.txt") ==="
echo "Next, on EACH node: ssh root@<host>, cd into the repo, nix-shell simgrid-chuc-validation/shell.nix"
