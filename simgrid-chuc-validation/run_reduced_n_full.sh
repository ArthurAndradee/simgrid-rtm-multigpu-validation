#!/usr/bin/env bash
# run_reduced_n_full.sh — orchestrates the full 2026-08-14 reduced-N
# session: 12 configs total = 6 REAL (3n+4n x 1/10/25gbit, genuine
# distributed MPI, N=1800) + 6 SIMULATED (3n+4n x 1/10/25gbit, N=1800,
# same-hardware A100 replacement for the earlier chicoree/H200 numbers).
# See REDUCED_N_RUNBOOK.md for the full rationale.
#
# Run from the HEAD node of a 4-chuc allocation, as user aandrade, with
# $OAR_NODE_FILE set (inside the OAR job) or HOSTS_OVERRIDE exported.
#
# TIME BUDGET: 110 min total (2026-08-14 17:05-18:55). Structure, in order:
#   1. Bootstrap (Nix x4 nodes, build bin/dc BACKEND=cuda) ~15 min
#   2. Smoke test (2-rank real cross-node MPI, <1 min) -- catches SSH/UCX
#      problems immediately instead of deep into a real run
#   3. Real 4-node, all 3 bands (needs ALL 4 real GPUs -- no simulation can
#      run concurrently without contending for the same physical GPUs)
#   4. Real 3-node (uses only 3 of 4 hosts) RUNS CONCURRENTLY WITH the full
#      6-config simulation (which only needs 1 real node) confined to the
#      4th, EXCLUDED host -- no GPU contention, since they never touch the
#      same physical GPU. This is the key time-saving move: ~15-18 min for
#      both instead of ~30+ min serial.
# Estimated total: ~45-50 min, leaving ~60 min of margin out of 110.
#
# If time runs out, priority order (steps already run in this order):
#   real 4n -> [real 3n + all 6 sim, in parallel] -- so whatever step is
#   mid-flight when time runs out, everything BEFORE it is already banked.
set -uo pipefail  # NOT -e: a failed phase should not silently abort the rest
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DIR/.." && pwd)"

if [ -n "${HOSTS_OVERRIDE:-}" ]; then
  read -r -a ALL_HOSTS <<< "$HOSTS_OVERRIDE"
elif [ -n "${OAR_NODE_FILE:-}" ]; then
  mapfile -t ALL_HOSTS < <(sort -u "$OAR_NODE_FILE")
else
  echo "ERROR: set HOSTS_OVERRIDE=\"host1 host2 host3 host4\" or run inside the OAR job." >&2
  exit 1
fi
[ "${#ALL_HOSTS[@]}" -ge 4 ] || { echo "ERROR: need 4 hosts, found ${#ALL_HOSTS[@]}" >&2; exit 1; }
HEAD="${ALL_HOSTS[0]}"
EXCLUDED_4TH="${ALL_HOSTS[3]}"  # run_reduced_n_real.sh's 3-node slice is
                                 # always hosts[0:3] (see its "hosts_for_this"
                                 # logic), so hosts[3] is always the one left
                                 # idle during the 3-node real phase.

export HOSTS_OVERRIDE="${ALL_HOSTS[*]}"
SECONDS=0

echo "############################################################"
echo "# STEP 1: bootstrap (Nix x4, build bin/dc BACKEND=cuda)"
echo "############################################################"
if ! MODE=bootstrap bash "$DIR/run_reduced_n_real.sh"; then
  echo ""
  echo "!!! BOOTSTRAP FAILED. Stopping here -- nothing downstream (smoke test,"
  echo "!!! real runs, even the simulation, which also needs this build's Nix"
  echo "!!! warmup) can succeed without this. Check the error above, fix it,"
  echo "!!! and re-run this script (idempotent -- already-done work is skipped)."
  exit 1
fi
echo "    [t=+${SECONDS}s]"

echo ""
echo "############################################################"
echo "# STEP 2: smoke test (2-rank real cross-node MPI)"
echo "############################################################"
if ! MODE=smoke bash "$DIR/run_reduced_n_real.sh"; then
  echo ""
  echo "!!! SMOKE TEST FAILED. Stopping here rather than burning walltime on"
  echo "!!! 6 real configs that would likely all fail the same way. Fix the"
  echo "!!! underlying issue (see error above) and re-run this script -- the"
  echo "!!! bootstrap step is idempotent (skips already-done work via"
  echo "!!! $DIR/.reduced_n_real_bootstrap_done)."
  exit 1
fi
echo "    [t=+${SECONDS}s]"

echo ""
echo "############################################################"
echo "# STEP 3: REAL 4-node, all 3 bands (uses all 4 real GPUs)"
echo "############################################################"
bash "$DIR/run_reduced_n_real.sh" 4
echo "    [t=+${SECONDS}s]"

echo ""
echo "############################################################"
echo "# STEP 4: REAL 3-node (hosts[0:3]) IN PARALLEL WITH"
echo "#         all 6 SIMULATED configs (on excluded host $EXCLUDED_4TH)"
echo "############################################################"
( bash "$DIR/run_reduced_n_real.sh" 3 2>&1 | sed 's/^/[REAL-3n] /' ) &
REAL3_PID=$!

( ssh "$EXCLUDED_4TH" "cd $REPO_ROOT && export XDG_CACHE_HOME=/tmp/nix-cache-local && nix develop --command bash -c 'bash simgrid-chuc-validation/run_validation_reduced_n.sh 3,4'" 2>&1 | sed 's/^/[SIM] /' ) &
SIM_PID=$!

wait "$REAL3_PID"; REAL3_RC=$?
wait "$SIM_PID"; SIM_RC=$?
echo "    [t=+${SECONDS}s] real-3n rc=$REAL3_RC, sim rc=$SIM_RC"

echo ""
echo "=== ALL STEPS ATTEMPTED at t=+${SECONDS}s. ==="
echo "Real results:      $DIR/results_reduced_n_real/<n>n_<band>/"
echo "Simulated results: $DIR/results_reduced_n/<n>n_<band>Gbps/"
echo "Check both trees for which configs actually completed (grep for"
echo "'^rank,total_time,msamples_per_s' in each dc.output)."
