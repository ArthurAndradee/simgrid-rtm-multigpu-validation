#!/usr/bin/env bash
# scripts/05-wait-and-run.sh -- wait on the FRONTEND until an advance
# reservation is Running, then start scripts/05-session-plan.sh on it, so no
# minute of the allocation is lost waiting for someone to launch it (job
# 2214702 ran 1h38 with nothing launched).
#
# Usage (from g5k/, on the frontend):
#   nohup setsid ./scripts/05-wait-and-run.sh <OAR_JOB_ID> > logs/wait_<job>.log 2>&1 &
# Cancel before the job starts: kill the PID printed in logs/wait_<job>.log.
set -uo pipefail
cd "$(dirname "$0")/.."   # -> g5k/
JOB=${1:?usage: 05-wait-and-run.sh <OAR_JOB_ID>}
SESSION_LOG="logs/session_${JOB}.log"
echo "[$(date +%T)] watcher PID $$ aguardando job $JOB"

while :; do
  st=$(oarstat -s -j "$JOB" 2>/dev/null | awk -F': ' '{print $2}')
  case "$st" in
    Running) break ;;
    Error|Terminated|"") echo "[$(date +%T)] job $JOB em estado '${st:-desconhecido}' -- desistindo"; exit 1 ;;
  esac
  sleep 20
done

# assigned_hostnames can lag the state switch by a few seconds
for _ in $(seq 1 18); do
  oarstat -f -j "$JOB" | grep -q '^ *assigned_hostnames = [a-z]' && break
  sleep 10
done

[ -e "$SESSION_LOG" ] && { echo "[$(date +%T)] $SESSION_LOG já existe -- plano já lançado? saindo"; exit 1; }
echo "[$(date +%T)] job $JOB Running -- iniciando 05-session-plan.sh (log: $SESSION_LOG)"
exec ./scripts/05-session-plan.sh "$JOB" > "$SESSION_LOG" 2>&1
