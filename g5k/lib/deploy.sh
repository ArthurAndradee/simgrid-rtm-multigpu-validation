# shellcheck shell=bash
# ---------------------------------------------------------------------------
# deploy.sh — kadeploy3 + kavlan + DHCP, factored out of the validated
# g5k/01-deploy.sh (unchanged behavior; g5k/01-deploy.sh itself is left in
# place as a standalone entry point / rollback path).
# ---------------------------------------------------------------------------

# deploy_run — kadeploy on all $OAR_NODE_FILE nodes, move them into the
# kavlan, bring the data NIC up with DHCP, verify IPv4 on every node.
deploy_run() {
  [ -n "${OAR_NODE_FILE:-}" ] || die "run inside an OAR job (oarsub ... -t deploy)"
  [ -n "${OAR_JOB_ID:-}" ] || die "OAR_JOB_ID not set — kavlan -V/-s require -j JOBID explicitly (does not fall back to job env auto-detection outside an interactive oarsub -C shell)"

  sort -u -V "$OAR_NODE_FILE" > "$NODES_FILE"
  log "reserved nodes ($(node_count)): $(nodes | paste -sd' ')"
  diary "Deploy iniciado em $(node_count) nós: $(nodes | paste -sd', ') (env=$DEPLOY_ENV)"

  log "kadeploy3: $DEPLOY_ENV on all nodes ..."
  kadeploy3 -f "$NODES_FILE" -e "$DEPLOY_ENV" -k "$HOME/.ssh/id_rsa.pub"

  log "kavlan: moving ${KAVLAN_DNS_SUFFIX} interfaces of ALL nodes ..."
  local vlan_id
  vlan_id=$(kavlan -V -j "$OAR_JOB_ID")
  [ -n "$vlan_id" ] || die "could not determine kavlan id (kavlan -V -j $OAR_JOB_ID) — did the OAR reservation include {type='kavlan'}/vlan=1?"
  log "  vlan id: $vlan_id"
  sed "s/\./-$KAVLAN_DNS_SUFFIX./" "$NODES_FILE" > "$STATE_DIR/nodes_$KAVLAN_DNS_SUFFIX.txt"
  kavlan -i "$vlan_id" -s -f "$STATE_DIR/nodes_$KAVLAN_DNS_SUFFIX.txt" -j "$OAR_JOB_ID"

  log "bringing $KAVLAN_IFACE up + DHCP on all nodes (parallel) ..."
  # pgrep -f matches the FULL remote command line, which for this very
  # invocation literally contains "dhclient.*$KAVLAN_IFACE" inside the
  # quoted pattern argument — unbracketed, pgrep always self-matches (rc=0)
  # regardless of whether dhclient is actually running, so the `|| dhclient`
  # fallback would never fire on a node that genuinely needs it. Masked so
  # far because dhclient happened to already be running in every session to
  # date (later IPv4 verification below would still catch a real miss as a
  # hard failure, just not self-heal it). Same bug class as lib/resilience.sh
  # ([.]/bin/dc) and lib/validate.sh ([i]perf3 -s) — [EMP] found + fixed
  # together 2026-07-17, job 2169626.
  all_nodes_script "
    set -e
    ip link set $KAVLAN_IFACE up
    pgrep -f '[d]hclient.*$KAVLAN_IFACE' >/dev/null || dhclient $KAVLAN_IFACE
  "

  log "verifying kavlan IPv4 on every node ..."
  : > "$STATE_DIR/kavlan_ips.txt"
  local h ip
  for h in $(nodes); do
    ip=$(ssh_root "$h" "ip -4 -o addr show dev $KAVLAN_IFACE | awk '{print \$4}'")
    [ -n "$ip" ] || die "$h has no IPv4 on $KAVLAN_IFACE (DHCP failed?)"
    echo "$h $ip" >> "$STATE_DIR/kavlan_ips.txt"
    log "  $h -> $ip"
  done

  # A fresh kadeploy always yields a fresh OS image with NO tc qdisc rules
  # configured yet, regardless of what $STATE_DIR/current_shaping.txt says
  # from a PREVIOUS (possibly expired, possibly different-nodes) OAR job —
  # that file is plain state in the NFS home, not tied to job/deploy
  # lifecycle. Found 2026-07-10 on job 2165368 (chuc-4/chuc-6): a stale
  # "25gbit" from the prior session's job 2165552 made
  # validate_mpi_cuda_ucx_smoke's native-mode smoke test refuse to run
  # (run_experiment's own, correct guard: native+shaping is unsafe). Reset
  # here so the recorded state always matches physical reality post-deploy.
  echo "off" > "$STATE_DIR/current_shaping.txt"

  diary "Deploy concluído. IPs kavlan: $(paste -sd', ' "$STATE_DIR/kavlan_ips.txt")"
}
