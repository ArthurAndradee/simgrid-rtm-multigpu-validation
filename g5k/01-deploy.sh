#!/usr/bin/env bash
# 01-deploy.sh — runs on the FRONTEND, inside the OAR job.
# Kadeploy on all reserved nodes, move the secondary NIC of every node into
# the kavlan, bring it up with DHCP and verify each node got an IPv4.
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh

[ -n "${OAR_NODE_FILE:-}" ] || die "run inside an OAR job (oarsub ... -t deploy)"
[ -n "${OAR_JOB_ID:-}" ] || die "OAR_JOB_ID not set — kavlan -V/-s require -j JOBID explicitly (it does NOT fall back to job env auto-detection outside an interactive oarsub -C shell)"
mkdir -p "$STATE_DIR"

# $OAR_NODE_FILE has one line per core; -V keeps a stable, human order
# (chuc-3 < chuc-4 < ...), which makes rank 0 / head node deterministic.
sort -u -V "$OAR_NODE_FILE" > "$NODES_FILE"
log "reserved nodes ($(node_count)): $(nodes | paste -sd' ')"

log "kadeploy3: $DEPLOY_ENV on all nodes ..."
kadeploy3 -f "$NODES_FILE" -e "$DEPLOY_ENV" -k "$HOME/.ssh/id_rsa.pub"

log "kavlan: moving ${KAVLAN_DNS_SUFFIX} interfaces of ALL nodes ..."
VLAN_ID=$(kavlan -V -j "$OAR_JOB_ID")
[ -n "$VLAN_ID" ] || die "could not determine kavlan id (kavlan -V -j $OAR_JOB_ID) — did the OAR reservation include {type='kavlan'}/vlan=1?"
log "  vlan id: $VLAN_ID"
sed "s/\./-$KAVLAN_DNS_SUFFIX./" "$NODES_FILE" > "$STATE_DIR/nodes_$KAVLAN_DNS_SUFFIX.txt"
kavlan -i "$VLAN_ID" -s -f "$STATE_DIR/nodes_$KAVLAN_DNS_SUFFIX.txt" -j "$OAR_JOB_ID"

log "bringing $KAVLAN_IFACE up + DHCP on all nodes (parallel) ..."
all_nodes_script "
  set -e
  ip link set $KAVLAN_IFACE up
  # idempotent: don't stack dhclient daemons on re-runs
  pgrep -f 'dhclient.*$KAVLAN_IFACE' >/dev/null || dhclient $KAVLAN_IFACE
"

log "verifying kavlan IPv4 on every node ..."
: > "$STATE_DIR/kavlan_ips.txt"
for h in $(nodes); do
  ip=$(ssh_root "$h" "ip -4 -o addr show dev $KAVLAN_IFACE | awk '{print \$4}'")
  [ -n "$ip" ] || die "$h has no IPv4 on $KAVLAN_IFACE (DHCP failed?)"
  echo "$h $ip" >> "$STATE_DIR/kavlan_ips.txt"
  log "  $h -> $ip"
done

log "deploy OK. Next: ./02-setup.sh"
