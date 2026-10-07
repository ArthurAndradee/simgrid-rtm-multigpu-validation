#!/usr/bin/env bash
# run_level2_guarded.sh -- run_level2_strongscale.sh under a free-RAM watchdog.
#
# Each smpirun at N=968 holds ~14 GB of real RAM (/dev/shm grows) despite
# smpi/shared-malloc:local; 60 parallel sims on chiclet-6 all died with
# SIGBUS and 8 on chiclet-7 hung the node (2026-10-02). This wrapper starts
# the sweep in its own process group and kills that whole group if available
# RAM falls below MIN_AVAIL_MB, so the node survives a bad JOBS choice.
#
# Usage (on a DEDICATED node, never the session/control node):
#   setsid nohup ./run_level2_guarded.sh <jobs> [np-filter] > guard.log 2>&1 &
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBS=${1:?usage: run_level2_guarded.sh <jobs> [np-filter]}
NP_FILTER=${2:-}
: "${MIN_AVAIL_MB:=40000}"
SWEEP_LOG=${SWEEP_LOG:-$DIR/l2sweep_$(hostname -s).log}

cd "$DIR"
setsid ./run_level2_strongscale.sh "$JOBS" "$NP_FILTER" > "$SWEEP_LOG" 2>&1 < /dev/null &
pgid=$!
echo "$(date +%T) sweep pgid=$pgid jobs=$JOBS min_avail=${MIN_AVAIL_MB}MB log=$SWEEP_LOG"
while kill -0 "$pgid" 2>/dev/null; do
  avail=$(free -m | awk '/Mem/{print $7}')
  echo "$(date +%T) avail=${avail}MB shm=$(df --output=used -m /dev/shm | tail -1 | tr -d ' ')MB sims=$(pgrep -c -f '[b]in_simgrid_l2/dc') done=$(grep -c '^done' "$SWEEP_LOG") failed=$(grep -c '^FAILED' "$SWEEP_LOG")"
  if [ "$avail" -lt "$MIN_AVAIL_MB" ]; then
    echo "$(date +%T) MEMORIA BAIXA (${avail}MB) -- matando grupo $pgid"
    kill -TERM -- "-$pgid"; sleep 5; kill -KILL -- "-$pgid" 2>/dev/null
    break
  fi
  sleep 15
done
echo "$(date +%T) fim"
