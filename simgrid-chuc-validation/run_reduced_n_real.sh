#!/usr/bin/env bash
# run_reduced_n_real.sh — REAL (not simulated) distributed Fletcher/RTM run
# at the reduced anchor N=1800, across a genuine multi-node MPI job on 3 or
# 4 real chuc nodes. Companion to run_validation_reduced_n.sh (the
# simulated side of this comparison) -- see REDUCED_N_RUNBOOK.md.
#
# WHY THIS SCRIPT (instead of reusing g5k/01-05*.sh unmodified as originally
# planned): the 2026-08-14 chuc allocation is a STANDARD job (no `-t
# deploy`), and g5k/01-deploy.sh hard-requires a deploy job (kadeploy3 to
# reimage the OS + kavlan for network isolation). Rather than resubmit
# (loses the scheduled slot, wastes walltime) this reimplements the same
# real-execution RECIPE -- same UCX/pml_ucx_tls fix, same driver bridge, same
# mpirun flags -- as g5k/lib/run.sh / 05-run.sh (read for reference, not
# modified, not sourced) but bootstraps via `sudo-g5k` + a manual Nix
# install (same pattern already validated this session on chuc-7/chuc-8/
# chicoree-1) instead of kadeploy3, and shapes bandwidth on the PRODUCTION
# interface directly (the whole node is exclusively ours for the job's
# duration either way) instead of a kavlan-isolated one.
#
# BUILDDIR left at the Makefile default ("bin") for BACKEND=cuda -- do NOT
# run this concurrently with run_validation_reduced_n.sh's BACKEND=
# simgrid_cuda build on the SAME node (that one uses BUILDDIR=bin_sim
# specifically so the two can coexist on shared NFS). The 4-node real
# config uses ALL 4 real GPUs so it must not overlap with ANY simulation;
# the 3-node real config only uses 3 of the 4 hosts, so it is SAFE to run
# concurrently with a simulation confined to the excluded 4th host -- see
# run_reduced_n_full.sh, which orchestrates exactly this for time budget
# reasons (110 min walltime, 12 total configs).
#
# Modes (env var MODE, default "run"):
#   MODE=bootstrap   only bootstrap Nix + build bin/dc + driver bridge on
#                     all 4 hosts (idempotent -- writes a marker file, safe
#                     to call multiple times / from multiple invocations)
#   MODE=smoke       quick 2-rank real cross-node MPI hello-world (no GPU
#                     work), to catch SSH/UCX/mpirun issues in <1 min
#                     instead of discovering them deep into a real run
#   MODE=run         the actual experiment runs (default) -- assumes
#                     bootstrap already done (calls it if the marker is
#                     missing, so standalone invocation still works)
#
# Usage (from the HEAD node of a 4-chuc allocation, as user aandrade):
#   bash simgrid-chuc-validation/run_reduced_n_real.sh <node-list e.g. 3,4>
#
# Host discovery: HOSTS_OVERRIDE="chuc-x... chuc-y..." env var, else
# $OAR_NODE_FILE (deduplicated).
set -uo pipefail  # NOT -e: one bad config shouldn't abort the whole session
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DIR/.." && pwd)"
cd "$REPO_ROOT"

RESULTS_DIR="$DIR/results_reduced_n_real"
mkdir -p "$RESULTS_DIR"
BOOTSTRAP_MARKER="$DIR/.reduced_n_real_bootstrap_done"

MODE="${MODE:-run}"
NODE_LIST="${1:-3,4}"
IFS=',' read -r -a NODE_COUNTS_TO_RUN <<< "$NODE_LIST"

if [ -n "${HOSTS_OVERRIDE:-}" ]; then
  read -r -a ALL_HOSTS <<< "$HOSTS_OVERRIDE"
elif [ -n "${OAR_NODE_FILE:-}" ]; then
  mapfile -t ALL_HOSTS < <(sort -u "$OAR_NODE_FILE")
else
  echo "ERROR: set HOSTS_OVERRIDE=\"host1 host2 host3 host4\" or run inside the OAR job." >&2
  exit 1
fi
# Required host count = the largest node-count actually requested (not a
# hardcoded 4): lets this script run correctly against a smaller ad-hoc
# allocation (e.g. a 3-node pre-session, run with node-list "3") without
# weakening the check for the real 4-node session (default node-list
# "3,4" still correctly requires 4).
max_needed=0
for n in "${NODE_COUNTS_TO_RUN[@]}"; do [ "$n" -gt "$max_needed" ] && max_needed=$n; done
[ "$max_needed" -lt 2 ] && max_needed=2  # smoke test needs >=2 for cross-node MPI
[ "${#ALL_HOSTS[@]}" -ge "$max_needed" ] || { echo "ERROR: need >=$max_needed allocated hosts for node-list '$NODE_LIST', found ${#ALL_HOSTS[@]}: ${ALL_HOSTS[*]}" >&2; exit 1; }
HEAD="${ALL_HOSTS[0]}"
echo "=== [$MODE] Allocated hosts: ${ALL_HOSTS[*]} (head: $HEAD) ==="

SECONDS=0
log_elapsed() { echo "    [t=+${SECONDS}s elapsed since script start]"; }

STENCIL=4; ABSORPTION=2
DX=1e-1; DY=1e-1; DZ=1e-1; DT=1e-6; TIME_MAX=1e-4
N=1800
SIZE=$(( N - 2*STENCIL - 2*ABSORPTION ))  # 1788
RANKS_PER_NODE=4
BANDWIDTHS=(1gbit 10gbit 25gbit)
NET_LAT="22.7us"
BRIDGE_PATH=/tmp/nv-bridge-reducedn
# BUG FIX (2026-08-17, live): $HOME (and therefore the default
# ~/.cache/nix) is NFS-shared across all 4 chuc nodes. Nix's fetcher/eval
# caches there are backed by SQLite, which does NOT handle concurrent
# access reliably over NFS -- confirmed live: 4 nodes running `nix develop`
# at once produced "SQLite database is busy (SQLITE_PROTOCOL)" warnings and
# a genuinely stuck "waiting for another Nix process" lock that outlived
# even the process holding it (stale flock over NFS after a kill -9).
# Fix: point XDG_CACHE_HOME at a per-node LOCAL (non-NFS) path for every
# nix invocation below, so the 4 nodes' concurrent `nix develop` calls never
# touch the same cache files at all.
NIX_CACHE_ENV='export XDG_CACHE_HOME=/tmp/nix-cache-local'
# BUG FIX (2026-08-14, caught live on the 3-node pre-session): UCX
# (g5k/05-run.sh's own PML) failed immediately on any real multi-rank-per-
# node run (fine at 1 rank/node in the smoke test, which never exercises
# intra-node shared-memory transport) with "no active messages transport
# ... self/memory - Destination is unreachable, tcp/lo - Destination is
# unreachable, sysv/memory/posix/memory/cma/memory". Root cause: chuc's
# production interface is a Linux BRIDGE (`br0`, confirmed via `ip route
# get 8.8.8.8` and `ip addr` on chuc-1/2/8 -- `ens15f0np0` is br0's actual
# slave NIC, the IP itself lives on br0). UCX's own device enumeration
# does not recognize bridge devices as usable at all (confirmed via the
# live warning: "network device 'br0' is not available, please use one or
# more of: 'lo'(tcp), 'rocep134s0f0:1'(ib)") -- setting UCX_NET_DEVICES=br0
# does NOT fix this (tried live, same failure), and the underlying slave
# NIC has no IP of its own to bind to either.
#
# FIX: bypass UCX's PML entirely and use OpenMPI's own native TCP BTL
# instead (`--mca pml ob1 --mca btl tcp,self,sm --mca btl_tcp_if_include
# br0`) -- OMPI's tcp BTL does plain socket()/bind() against the named
# interface's IP with no special device-enumeration restrictions, and
# bridges work with it exactly like any other interface. Confirmed live:
# a 12-rank (3-node) `mpirun ... hostname` that failed identically under
# UCX succeeded immediately under this BTL. This app never needs UCX's
# GPU/CUDA-aware transport features anyway -- halo exchange already
# stages through host memory before MPI_Isend/Irecv (device_data.cu's
# dc_device_extract_halo_face does cudaMemcpy device->host first), so
# plain host-memory TCP is exactly what real MPI traffic here already was.
PML_MCA="--mca pml ob1 --mca btl tcp,self,sm"
BTL_IFACE_VAL=$(ssh "$HEAD" "ip route get 8.8.8.8 2>/dev/null | grep -oP 'dev \K\S+'" | head -1)
if [ -z "$BTL_IFACE_VAL" ]; then
  echo "WARNING: could not detect production interface on $HEAD for btl_tcp_if_include -- OMPI will guess, may pick the wrong one." >&2
  BTL_IFACE_MCA=""
else
  echo "  btl_tcp_if_include=$BTL_IFACE_VAL (detected on $HEAD)"
  BTL_IFACE_MCA="--mca btl_tcp_if_include $BTL_IFACE_VAL"
fi

do_bootstrap() {
  echo "=== [t=+${SECONDS}s] Bootstrapping Nix on all 4 nodes (parallel) ==="
  for h in "${ALL_HOSTS[@]}"; do
    ( ssh -o StrictHostKeyChecking=accept-new "$h" \
        'command -v nix >/dev/null 2>&1 && exit 0
         sudo-g5k bash -c "mkdir -p /tmp/nix /nix; mount --bind /tmp/nix /nix; sh <(curl -fsSL https://nixos.org/nix/install) --daemon --yes"' \
        > "/tmp/bootstrap_${h}.log" 2>&1 && echo "  $h: nix ready" || echo "  $h: BOOTSTRAP FAILED, see /tmp/bootstrap_${h}.log" ) &
  done
  wait
  log_elapsed

  for h in "${ALL_HOSTS[@]}"; do
    ssh "$h" "cd $REPO_ROOT && git config --global --add safe.directory '*'" &
  done
  wait

  # CRITICAL: mpirun's remote orted daemon launch execs the SAME absolute
  # /nix/store/<hash>-... paths on every node (no --prefix tricks, per
  # g5k/05-run.sh's own comment -- "identical /nix/store on all nodes"),
  # but /nix here is a per-node LOCAL bind-mount (/tmp/nix), NOT NFS-shared
  # -- each node has to have INDEPENDENTLY fetched the exact same flake
  # packages into ITS OWN local store for those paths to exist there too.
  # Content-addressed Nix store paths are deterministic (same derivation
  # hash -> same path on every machine), so this works as long as every
  # node runs `nix develop` against the SAME flake.lock at least once.
  # Build on head + warm up the other 3's devShell CONCURRENTLY (both are
  # independent, no reason to serialize and waste walltime).
  #
  # PROFILE=akypuera: WITHOUT this, the Makefile does not link -laky at
  # all (see Makefile lines ~21-24) -- the binary would be built with ZERO
  # tracing support, no rastro-*.rst files ever generated regardless of
  # runtime env vars, silently losing ALL 6 real configs' ME (masking
  # effectiveness) data with no error message. Matches g5k/03-build.sh's
  # own default (PROFILE=akypuera).
  echo "=== [t=+${SECONDS}s] Building dc (BACKEND=cuda, ARCH=sm_80, PROFILE=akypuera) on $HEAD + warming up devShell on the other 3 (parallel) ==="
  # Explicit exit-code capture, NOT just `wait $PID` with no check: under
  # `set -uo pipefail` (deliberately no -e, see script header), a failed
  # build here would otherwise go completely unnoticed -- the script would
  # still touch BOOTSTRAP_MARKER, the smoke test (plain `hostname`, no
  # bin/dc involved) would still PASS and report false confidence, and the
  # actual failure would only surface deep into Step 3/4's real runs,
  # burning walltime before anyone notices bin/dc was never built.
  ssh "$HEAD" "cd $REPO_ROOT && $NIX_CACHE_ENV && nix develop --command bash -c 'cd $REPO_ROOT && make clean >/dev/null 2>&1; make all BACKEND=cuda ARCH=sm_80 PROFILE=akypuera'" 2>&1 | tail -30 &
  BUILD_PID=$!
  for h in "${ALL_HOSTS[@]:1}"; do
    ssh "$h" "cd $REPO_ROOT && $NIX_CACHE_ENV && nix develop --command true" > "/tmp/warmup_${h}.log" 2>&1 &
  done
  wait "$BUILD_PID"; local build_rc=$?
  wait
  log_elapsed

  if [ "$build_rc" -ne 0 ] || ! ssh "$HEAD" "[ -x $REPO_ROOT/bin/dc ]"; then
    echo "!!! BUILD FAILED (rc=$build_rc) or bin/dc missing/not executable on $HEAD -- ABORTING." >&2
    echo "!!! Do NOT proceed to the smoke test or real runs; the smoke test would" >&2
    echo "!!! pass anyway (it doesn't touch bin/dc) and give false confidence." >&2
    return 1
  fi
  echo "  bin/dc built OK on $HEAD."

  echo "=== [t=+${SECONDS}s] Driver bridge on all 4 nodes ==="
  for h in "${ALL_HOSTS[@]}"; do
    ssh "$h" "mkdir -p $BRIDGE_PATH
      for lib in libcuda.so.1 libnvidia-ptxjitcompiler.so.1; do
        for d in /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib; do
          [ -e \"\$d/\$lib\" ] && ln -sf \"\$d/\$lib\" \"$BRIDGE_PATH/\$lib\" && break
        done
      done" &
  done
  wait
  log_elapsed
  touch "$BOOTSTRAP_MARKER"
}

shape_hosts() {
  # BUG FIX (2026-08-14 review): the earlier version of this function
  # ("shape_all") always iterated ALL_HOSTS regardless of which hosts were
  # actually part of the experiment being configured. During the 3-node
  # real phase (run_reduced_n_full.sh's Step 4), that would have applied
  # bandwidth shaping to the 4th, EXCLUDED host too -- the one concurrently
  # running the simulation via SSH from the orchestrator -- throttling its
  # SSH/NFS traffic (at 1gbit, potentially badly) for no reason, since it
  # is not part of this real config at all. Now takes an explicit host
  # list and only touches those.
  local rate_g5k="$1" delay="$2"; shift 2
  local hosts=("$@")
  for h in "${hosts[@]}"; do
    ssh "$h" "sudo-g5k bash -c '
      IFACE=\$(ip route get 8.8.8.8 2>/dev/null | grep -oP \"dev \K\S+\" | head -1)
      tc qdisc del dev \$IFACE root 2>/dev/null || true
      if [ \"$rate_g5k\" != \"off\" ]; then
        num=\$(echo $rate_g5k | grep -oE \"[0-9]+\")
        case \"$rate_g5k\" in
          *gbit) bps=\$((num * 1000000000)) ;;
          *mbit) bps=\$((num * 1000000)) ;;
        esac
        burst=\$((bps / 8 / 500)); [ \$burst -lt 65536 ] && burst=65536
        tc qdisc add dev \$IFACE root handle 1: tbf rate $rate_g5k burst \${burst}b latency 50ms
        [ -n \"$delay\" ] && tc qdisc add dev \$IFACE parent 1: handle 10: netem delay $delay
      fi
    '" &
  done
  wait
}

do_smoke_test() {
  echo "=== [t=+${SECONDS}s] SMOKE TEST 1/2: nvidia-smi on all 4 hosts (GPUs visible?) ==="
  local gpu_ok=0
  for h in "${ALL_HOSTS[@]}"; do
    if ssh "$h" "nvidia-smi -L" > "/tmp/smoke_gpu_${h}.log" 2>&1; then
      echo "  $h: $(grep -c 'GPU ' "/tmp/smoke_gpu_${h}.log") GPU(s) visible"
    else
      echo "  $h: nvidia-smi FAILED, see /tmp/smoke_gpu_${h}.log"
      gpu_ok=1
    fi
  done
  if [ "$gpu_ok" -ne 0 ]; then
    echo "SMOKE TEST FAILED -- at least one host can't see its GPUs. Fix this before"
    echo "spending walltime on real/simulated runs that need every host's 4 GPUs."
    return 1
  fi

  echo "=== [t=+${SECONDS}s] SMOKE TEST 2/2: 2-rank real MPI hello-world across ${ALL_HOSTS[0]} + ${ALL_HOSTS[1]} ==="
  # BUG FIX (2026-08-14, caught live on the 3-node pre-session): this
  # script's documented usage is "run from the HEAD node", but nothing
  # enforced that -- run from any OTHER machine (e.g. the frontend, or a
  # different chuc/chiclet the operator happens to be sitting on), and the
  # hostfile below would be written to LOCAL /tmp on that OTHER machine,
  # while `ssh "$HEAD" ... --hostfile $hf ...` tries to open it on $HEAD,
  # where it never existed ("PRTE was unable to open the hostfile"). Now
  # writes the hostfile directly on $HEAD via ssh, so it's correct
  # regardless of which machine actually invokes this script.
  local hf=/tmp/hostfile_smoke.txt
  ssh "$HEAD" "printf '%s slots=1\n%s slots=1\n' '${ALL_HOSTS[0]}' '${ALL_HOSTS[1]}' > $hf"
  if ssh "$HEAD" "cd $REPO_ROOT && $NIX_CACHE_ENV && nix develop --command bash -c '
      mpirun --allow-run-as-root -np 2 --hostfile $hf \
        $PML_MCA $BTL_IFACE_MCA \
        hostname
    '" ; then
    echo "SMOKE TEST PASSED -- GPUs visible on all hosts, real cross-node MPI works."
    echo "Proceeding with confidence."
    return 0
  else
    echo "SMOKE TEST FAILED -- real cross-node MPI is broken. DO NOT proceed with the"
    echo "full real-run plan blind; debug this (SSH mesh? UCX transport? firewall?)"
    echo "before spending walltime on the 6 real configs. Consider falling back to"
    echo "a -t deploy allocation (g5k/01-05*.sh) if this can't be fixed quickly."
    return 1
  fi
}

case "$MODE" in
  bootstrap) do_bootstrap; exit $? ;;
  smoke)
    if [ ! -f "$BOOTSTRAP_MARKER" ]; then
      do_bootstrap || { echo "Bootstrap failed -- not running the smoke test on a broken build." >&2; exit 1; }
    fi
    do_smoke_test; exit $?
    ;;
esac

# MODE=run (default): ensure bootstrap happened, then run configs.
if [ ! -f "$BOOTSTRAP_MARKER" ]; then
  do_bootstrap || { echo "Bootstrap failed -- aborting before any real runs." >&2; exit 1; }
fi

run_one() {
  local nodes=$1 band=$2 host_list=$3
  local total_hosts=$(( nodes * RANKS_PER_NODE ))
  local label="${nodes}n_${band}"
  local hostfile="/tmp/hostfile_reducedn_${label}.txt"
  local run_dir="$RESULTS_DIR/$label"
  mkdir -p "$run_dir"

  if grep -q "^rank,total_time,msamples_per_s" "$run_dir/dc.output" 2>/dev/null; then
    echo "=== [t=+${SECONDS}s] $label: already done, skipping ==="
    return
  fi

  # BUG FIX (2026-08-14, same class as the smoke test's): write the
  # hostfile directly on $HEAD via ssh, not to local /tmp -- this script
  # may be invoked from a machine other than $HEAD (frontend, a different
  # chuc/chiclet), in which case a locally-written hostfile would not
  # exist where mpirun (running on $HEAD) tries to read it.
  local hostfile_content
  hostfile_content=$(printf '%s\n' $host_list | awk '{print $1" slots=4"}')
  ssh "$HEAD" "cat > $hostfile" <<< "$hostfile_content"
  local hosts_arr=($host_list)

  echo ""
  echo "=== [t=+${SECONDS}s] REAL $label (N=$N size=$SIZE hosts=$total_hosts) ==="
  shape_hosts "$band" "$NET_LAT" "${hosts_arr[@]}"

  ssh "$HEAD" "cd $REPO_ROOT && \
    export LD_LIBRARY_PATH=$BRIDGE_PATH:\${LD_LIBRARY_PATH:-} && \
    export RST_BUFFER_SIZE=1073741824 && \
    $NIX_CACHE_ENV && \
    nix develop --command bash -c '
      export LD_LIBRARY_PATH=$BRIDGE_PATH:\$LD_LIBRARY_PATH
      rm -f rastro-*.rst dc.trace dc.csv
      mpirun --allow-run-as-root -np $total_hosts --hostfile $hostfile \
        --map-by slot --bind-to numa $PML_MCA $BTL_IFACE_MCA \
        -x PATH -x LD_LIBRARY_PATH -x RST_BUFFER_SIZE \
        ./bin/dc --size-x=$SIZE --size-y=$SIZE --size-z=$SIZE \
          --absorption=$ABSORPTION --dx=$DX --dy=$DY --dz=$DZ --dt=$DT --time-max=$TIME_MAX --skip-output \
        2>&1 | tee dc.output
      if ls rastro-*.rst >/dev/null 2>&1; then
        # BUG FIX (2026-08-17, live, root-caused properly after a first
        # wrong guess): aky_converter CRASHED (std::out_of_range, no send
        # for this receive yet) on all 3 real 4-node (16-rank) configs, but
        # NOT the 3-node ones. First attempted fix (-i/--ignore-errors +
        # numeric file ordering) suppressed the crash but produced an
        # EMPTY dc.csv -- the -i output itself contains malformed LINK
        # records for the unmatched send/receive pairs (confirmed via
        # pj_dump: field count 6 vs definition 7 on a LINK line), which
        # then crashes pj_dump too, even with -z/--ignore-incomplete-links.
        # ROOT CAUSE (isolated live, testing 2-file subsets and the full
        # 16-file set): the coordinator (rank 0) legitimately point-to-point
        # MPI_Sends its partition-info struct to all 15 workers at startup
        # AND separately exchanges Cartesian-neighbor halos with several of
        # them later -- with real (not simulated) per-machine clocks across
        # 4 distinct physical hosts, a handful of these send/receive pairs
        # get recorded with an apparent causality inversion (clock skew),
        # which aky_converter cannot resolve without a proper
        # rastro_timesync-generated sync file (the -z/--sync=SYNC_FILE
        # flag) -- and rastro_timesync itself is not present in this Nix
        # package (only aky_converter is), so that proper fix is not
        # available here.
        # ACTUAL FIX: aky_converter -l/--no-links skips converting
        # point-to-point LINK events entirely, which is exactly where the
        # skew-triggered mismatch lives -- and the fidelity-error pipeline
        # (compute_fidelity_error dot R, compute_me function) only ever
        # reads STATE rows (MPI_Irecv/MPI_Waitall), never LINK rows, so
        # this loses nothing we actually use. Confirmed live: -l alone (no -i needed)
        # produces a clean trace, zero errors, and pj_dump then succeeds
        # with 60000+ valid State rows including MPI_Irecv/MPI_Waitall.
        # g5k/05-run.sh has the same underlying vulnerability in its own
        # aky_converter call (no -l, no -i, no -z) -- not fixed there, only here.
        aky_converter -l \$(ls rastro-*.rst | sort -t- -k2 -n) > dc.trace
        pj_dump -z -l 9 dc.trace | grep ^State > dc.csv || true
      fi
    '" 2>&1 | tee "$run_dir/dc.output.raw"

  for f in dc.trace dc.csv dc.output; do
    ssh "$HEAD" "[ -f $REPO_ROOT/$f ] && cat $REPO_ROOT/$f" > "$run_dir/$f" 2>/dev/null || true
    ssh "$HEAD" "rm -f $REPO_ROOT/$f $REPO_ROOT/rastro-*.rst" 2>/dev/null || true
  done

  cat > "$run_dir/metadata.txt" <<EOF
# REAL run (not simulated) -- reduced N=$N reference for Level 1's
# hardware-mismatch fix (see LEVEL2_FINDINGS.md sec 6.5 / REDUCED_N_RUNBOOK.md)
label: $label
nodes: $nodes
total_hosts: $total_hosts
anchor_N: $N (reduced -- compare ONLY against results_reduced_n/, not Table 3)
cuda_size: $SIZE
bandwidth: $band
net_lat: $NET_LAT
hostfile: $host_list
timestamp: $(date -Iseconds)
EOF
  log_elapsed
}

for nodes in "${NODE_COUNTS_TO_RUN[@]}"; do
  hosts_for_this="${ALL_HOSTS[*]:0:$nodes}"
  for band in "${BANDWIDTHS[@]}"; do
    run_one "$nodes" "$band" "$hosts_for_this"
  done
done

shape_hosts off "" "${ALL_HOSTS[@]}"
echo ""
echo "=== Done at t=+${SECONDS}s. Results in $RESULTS_DIR/<nodes>n_<band>/ ==="
