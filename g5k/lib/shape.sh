# shellcheck shell=bash
# ---------------------------------------------------------------------------
# shape.sh — tc tbf (+ optional netem) traffic shaping on the kavlan NIC of
# every node. Factored out of the validated g5k/04-shape.sh (unchanged
# behavior/rationale — see comments below, preserved from the original).
#
# Why tbf+tcp (and not shaping RDMA): RDMA/RoCE traffic bypasses the kernel
# qdisc entirely, so ANY tc-based limit is invisible to UCX rc/dc transports.
# Shaped experiments therefore MUST run with UCX_TLS=tcp (lib/run.sh does
# it, together with the validated --mca pml_ucx_tls fix). tbf burst is
# scaled with the rate (~2 ms worth of bytes) — a fixed small burst is far
# too coarse at 10/25 Gbit and starves the bucket.
# ---------------------------------------------------------------------------

# shape_off — remove shaping on every node.
shape_off() {
  log "removing shaping on $KAVLAN_IFACE on all nodes"
  all_nodes_script "tc qdisc del dev $KAVLAN_IFACE root 2>/dev/null || true"
  echo "off" > "$STATE_DIR/current_shaping.txt"
}

# shape_apply <rate> [delay] — e.g. shape_apply 1gbit / shape_apply 10gbit 22.7us
shape_apply() {
  local rate=$1 delay=${2:-}
  [ -n "$rate" ] || die "shape_apply: rate required"

  if [ "$rate" = off ]; then
    shape_off
    return
  fi

  local num unit bps
  num=${rate//[!0-9]/}; unit=${rate//[0-9]/}
  case $unit in
    gbit) bps=$((num * 1000000000)) ;;
    mbit) bps=$((num * 1000000)) ;;
    kbit) bps=$((num * 1000)) ;;
    *) die "unsupported rate unit '$unit' (use kbit/mbit/gbit)" ;;
  esac
  local burst=$((bps / 8 / 500)); [ "$burst" -lt 65536 ] && burst=65536

  local cmd="tc qdisc del dev $KAVLAN_IFACE root 2>/dev/null || true
tc qdisc add dev $KAVLAN_IFACE root handle 1: tbf rate $rate burst ${burst}b latency 50ms"
  if [ -n "$delay" ]; then
    cmd="$cmd
tc qdisc add dev $KAVLAN_IFACE parent 1:1 handle 10: netem delay $delay limit 100000"
  fi

  log "applying tbf rate=$rate burst=${burst}B ${delay:+netem delay=$delay }on all nodes"
  all_nodes_script "$cmd"

  log "verification (tc qdisc show):"
  local h
  for h in $(nodes); do
    echo "--- $h"
    ssh_root "$h" "tc qdisc show dev $KAVLAN_IFACE"
  done
  echo "$rate ${delay:-}" > "$STATE_DIR/current_shaping.txt"
}

current_shaping() { cat "$STATE_DIR/current_shaping.txt" 2>/dev/null || echo "off"; }
