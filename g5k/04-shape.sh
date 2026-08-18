#!/usr/bin/env bash
# 04-shape.sh — runs on the FRONTEND. Egress traffic shaping on the kavlan
# interface of EVERY node (not just two).
#
#   ./04-shape.sh 1gbit            # tbf @1gbit on all nodes
#   ./04-shape.sh 10gbit 22.7us    # tbf + netem delay (matches SimGrid lat)
#   ./04-shape.sh off              # remove shaping everywhere
#
# Why tbf+tcp (and not shaping RDMA): RDMA/RoCE traffic bypasses the kernel
# qdisc entirely, so ANY tc-based limit is invisible to UCX rc/dc transports.
# Shaped experiments therefore MUST run with UCX_TLS=tcp (05-run.sh does it).
# tbf burst is scaled with the rate (~2 ms worth of bytes) — a fixed
# "burst 10mbit" is far too coarse at 10/25 Gbit and starves the bucket.
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh
require_nodes_file

RATE=${1:?usage: 04-shape.sh <rate|off> [delay e.g. 22.7us]}
DELAY=${2:-}

if [ "$RATE" = off ]; then
  log "removing shaping on $KAVLAN_IFACE on all nodes"
  all_nodes_script "tc qdisc del dev $KAVLAN_IFACE root 2>/dev/null || true"
  exit 0
fi

# rate -> bits/s (accepts Ngbit / Nmbit / Nkbit)
num=${RATE//[!0-9]/}; unit=${RATE//[0-9]/}
case $unit in
  gbit) bps=$((num * 1000000000)) ;;
  mbit) bps=$((num * 1000000)) ;;
  kbit) bps=$((num * 1000)) ;;
  *) die "unsupported rate unit '$unit' (use kbit/mbit/gbit)" ;;
esac
# burst = 2 ms at line rate, floor 64 KiB (must exceed rate/HZ)
burst=$((bps / 8 / 500)); [ "$burst" -lt 65536 ] && burst=65536

CMD="tc qdisc del dev $KAVLAN_IFACE root 2>/dev/null || true
tc qdisc add dev $KAVLAN_IFACE root handle 1: tbf rate $RATE burst ${burst}b latency 50ms"
if [ -n "$DELAY" ]; then
  # netem under tbf adds one-way delay; limit sized generously for high BDP
  CMD="$CMD
tc qdisc add dev $KAVLAN_IFACE parent 1:1 handle 10: netem delay $DELAY limit 100000"
fi

log "applying tbf rate=$RATE burst=${burst}B ${DELAY:+netem delay=$DELAY }on all nodes"
all_nodes_script "$CMD"

log "verification (tc qdisc show):"
for h in $(nodes); do
  echo "--- $h"
  ssh_root "$h" "tc qdisc show dev $KAVLAN_IFACE"
done
echo "$RATE ${DELAY:-}" > "$STATE_DIR/current_shaping.txt"
