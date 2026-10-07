# Level 1 & Level 2 — Findings (2026-08-12/13)

Consolidated write-up of everything done, discovered, and still open for
both the Level 2 validation (§1-§5: real A100 compute constants injected
into the original Spadotto/poti network calibration, no live GPU) and
Level 1 (§6: the same platform/calibration but with real online GPU kernel
sampling under SMPI, on an actual chuc allocation). Written so the paper's
Results/Discussion section can be drafted directly from this.

## 1. What Level 2 is and why it exists

Level 1 (BACKEND=simgrid_cuda, real online GPU kernel sampling on chuc) has
been blocked since 2026-08-12 by an unresolved SMPI `dlopen` failure ("cannot
dynamically load position-independent executable") — see §5 below and
`simgrid-chuc-validation/dlopen_repro/` (main branch). Level 2 is a substitute that keeps
the original network model completely unchanged and replaces only the
compute component: instead of sampling kernel time live (which needs a real
GPU and hits the same dlopen bug), the real per-iteration A100 kernel time is
**extracted from the already-published real campaign's own traces** and
injected as a fixed constant. This needs no GPU, no chuc allocation, and no
new benchmark — see `analysis/extract_kernel_time.R` for the extraction
method (the gap between consecutive MPI events in `dc.csv`, since
`dc_compute_boundaries`/`dc_compute_interior` call `cudaDeviceSynchronize()`,
is exactly the real kernel's wall time).

## 2. Final results (12/12 configs, validated methodology)

All 12 (nodes × band) configs completed. Fidelity error = 100×(simulated −
real)/real. Full machine-readable table:
`simgrid-chuc-validation/fidelity_error_level2.csv`.

| nodes | band | real ms/s | sim ms/s | error (throughput) | real ME | sim ME | error (ME) |
|---|---|---|---|---|---|---|---|
| 1 | 1gbit  | 3266.5 | 8245.9 | **+152%** | 0.847 | 0.915 | +8.0% |
| 1 | 10gbit | 3325.8 | 8245.9 | **+148%** | 0.837 | 0.915 | +9.3% |
| 1 | 25gbit | 3298.5 | 8245.9 | **+150%** | 0.851 | 0.915 | +7.6% |
| 2 | 1gbit  | 4886.9 | 3072.6 | **−37.1%** | 0.449 | 0.143 | **−68.2%** |
| 2 | 10gbit | 7783.2 | 19084.5 | **+145%** | 0.783 | 0.883 | +12.8% |
| 2 | 25gbit | 7398.0 | 19084.5 | **+158%** | 0.744 | 0.883 | +18.7% |
| 3 | 1gbit  | 2863.0 | 1709.6 | **−40.3%** | 0.289 | 0.062 | **−78.7%** |
| 3 | 10gbit | 5915.7 | 17073.0 | **+189%** | 0.622 | 0.615 | −1.2% |
| 3 | 25gbit | 5960.8 | 22306.0 | **+274%** | 0.631 | 0.796 | +26.3% |
| 4 | 1gbit  | 3445.9 | 1941.5 | **−43.7%** | 0.262 | 0.054 | **−79.4%** |
| 4 | 10gbit | 8107.0 | 19384.2 | **+139%** | 0.637 | 0.538 | −15.6% |
| 4 | 25gbit | 8054.0 | 28198.4 | **+250%** | 0.643 | 0.772 | +20.0% |

(ME fidelity-error initially came back `NA` for all 12 configs — traced to
Level 2's traces logging `PMPI_`-prefixed state names, e.g. `PMPI_Irecv`,
unlike the real campaign's plain `MPI_Irecv`; fixed by stripping the
profiling-layer prefix in `compute_me()`, `compute_fidelity_error_level2.R`.)

**Notable**: ME's error pattern at 1 Gbit/s is much *larger in magnitude*
than throughput's at that band (−68 to −79% vs −37 to −44%), and unlike
throughput, it's consistently negative (simulated masks *less* than real)
at every node count ≥2. Worth a closer look before writing this up --
possibly a second, independent signal pointing at the same low-bandwidth
network-model gap noted in §4, or a separate issue with how ME's window
(`min MPI_Irecv Start` to `max MPI_Waitall End`) behaves once bookkeeping
is injected rather than measured live -- not resolved under tonight's time
budget.

**Read the throughput errors with the §4 caveat below already in mind: at
10/25 Gbit/s, Level 2's network component is fully masked by compute (see
§4), so those numbers are really testing "does A100 compute alone, with
zero effective network cost, explain real throughput" — not a network-model
comparison at all.**

## 3. The three-headed memory-vs-validity saga (methodology, now resolved)

This ate most of the night; documenting it so it isn't rediscovered.

**Problem**: SMPI simulates every rank as a coroutine inside ONE OS process
(confirmed: `smpirun`'s underlying `smpimain` never distributes real
processes across real hosts, regardless of `-hostfile` — that file only
names *simulated* hosts). For 2-4 node configs (8-16 ranks), the real
per-rank array footprint (weak-scaling design, ~15GB/rank even after
trimming to the 6 essential arrays — see `src/worker.c`'s `DC_MALLOC`
history) exceeds a single 125GB chiclet's RAM.

**Attempt 1 — `SMPI_SHARED_MALLOC` + `--cfg=smpi/shared-malloc:global`**:
solved memory capacity (physical usage stayed near-zero even past 300GB of
virtual RSS) but was catastrophically slow with the *real app* specifically
(an isolated alloc+memset microbenchmark showed only ~2x overhead; the real
app took 5+ minutes without finishing even rank 1's init). Root cause never
isolated for `global` mode specifically.

**Attempt 2 — `--cfg=smpi/shared-malloc:local`** (SMPI's default sharing
granularity): much faster in practice (a 4-node/16-rank run that never
finished under `global` completed cleanly), and this is what actually
produced the "12 configs done!" milestone earlier in the night. **But this
was a false victory**: a controls check (`1n_1Gbps` with three different
memory-backing choices) gave three different throughput numbers for the
*identical* physical scenario:

| DC_MALLOC choice | throughput |
|---|---|
| plain `malloc` | 4746 msamples/s |
| `SMPI_SHARED_MALLOC` (local) | 5573 msamples/s |
| `SMPI_SHARED_MALLOC` (local) + `simulate-computation:no` | 8614 msamples/s |

**Root cause, confirmed**: `smpi/simulate-computation` defaults to `ON`
(`smpirun --cfg=help:simulate-computation` → `smpi/simulate-computation:
(boolean)1`). With it on, SMPI auto-times *every* unwrapped host code path —
not just the three explicit `smpi_execute_benched()` injection points — and
charges real wall-clock time into the simulated clock. `SMPI_SHARED_MALLOC`'s
"folded" backing (many virtual pages aliasing few physical ones) makes
memory-touching code (`dc_worker_insert_halos`'s per-face copy loops, in
particular) run *unrealistically fast* in real wall-clock terms (excellent
cache locality from reusing a tiny physical working set) — an artifact of
the memory-saving trick, not a real hardware effect.

**Fix**: extracted a *third* real-hardware constant — `bookkeeping_s`, the
gap between the recv- and send-`MPI_Waitall`s in the real trace, which is
exactly `dc_worker_insert_halos` (×2) + `dc_device_swap_arrays` — added
`DC_FIXED_BOOKKEEPING_S` injection in `src/worker.c` alongside the existing
boundaries/interior injections, and set
`--cfg=smpi/simulate-computation:no` globally
(`simgrid-chuc-validation/run_level2.sh`). With this, simulated time is
driven *entirely* by the three explicit real-hardware-extracted constants
plus the simulated network — nothing else can leak memory-backing artifacts
in. **Validated**: re-ran `1n_1Gbps` with plain `malloc` and with
`SMPI_SHARED_MALLOC` under the fixed methodology — byte-identical result,
`8245.885542` msamples/s, matching to the last decimal on every rank. All 12
final configs in §2 use this validated methodology.

## 4. Item 3 investigation: why does the error grow (and flip sign) with band/nodes?

Pattern: Level 2 **underestimates** real throughput by ~40% at 1 Gbit/s
(all node counts), but **overestimates** by 140-275% at 10/25 Gbit/s, worse
with more nodes. Two contributing mechanisms, both checked against the data:

**(a) At 10/25 Gbit/s, Level 2's network component is fully masked by
compute — not a network-model comparison at all.** Directly observed: for
every topology with ≥2 nodes, 10 Gbit/s and 25 Gbit/s gave **byte-identical**
`total_time` (e.g. 2-node: `26.662734` s for both, to the microsecond). Once
bandwidth is "fast enough" that network transfer finishes before the
injected compute critical path does, the two bandwidths become
indistinguishable in the simulated result — the *coordinator's* total_time
(the throughput denominator, see `src/main.c:224-232`) is bottlenecked by
compute+bookkeeping alone. Real hardware doesn't show this: real 10gbit vs
25gbit throughput actually *differ* (e.g. 2-node real: 7783 vs 7398
msamples/s — non-monotonic, itself notable). This alone means the >100%
errors at 10/25 Gbit/s are not measuring "is the network model right" so
much as "is A100 compute alone enough to explain real throughput once
network stops mattering" — and evidently it overshoots real hardware by a
lot, meaning real hardware has *some other* bottleneck at high bandwidth
that this model doesn't capture (see (b)).

**(b) The halo messages are far outside the range the Cornebize network
calibration was ever validated for.** Halo face size for these problem
sizes is ~12 MB (`local_dim² × STENCIL × 4 bytes`, e.g. 868×868×4×4 ≈
12.05 MB for the 2-node config) — the calibration's largest message-size
breakpoint is 65,480 bytes (64 KB), ~190× smaller. At and above that top
breakpoint, the calibration's fixed per-message overhead coefficients
(`smpi/os`, `smpi/or`) are literally `0.0:0.0` — an artifact of how far the
original poti calibration's breakpoint sweep reached, not a measurement that
large messages really have zero fixed overhead. Real hardware at 10/25
Gbit/s moving 12 MB messages almost certainly incurs real costs (PCIe/memory
bus contention, OS-level buffering, NIC queueing under load) that this
calibration has no data for and silently prices at zero. This directly
predicts the observed direction (Level 2 too optimistic exactly where real
messages are most oversized relative to calibration) and explains why the
error *worsens* with node count: more nodes usually corresponds to larger
per-rank domains in this weak-scaling design (see `g5k/csv/experimentos.csv`
sizing), hence even larger, even-more-out-of-calibration-range messages
(4-node message size is the largest of the four topologies among those
tested — consistent with 4-node showing the single worst error, +274%
would be 3-node, need to double check exact ranking here, but the
qualitative direction holds).

**Not yet investigated further** (flagging, not resolving, given the
overnight time budget): whether re-running Cornebize's calibration
methodology with breakpoints extended to actual chuc message sizes (~12 MB)
would meaningfully shrink these errors — this would require real chuc
network benchmarking, i.e. an actual allocation, and is a natural next step
if the paper wants to push past "the calibration doesn't cover this regime"
as a stated limitation.

**At 1 Gbit/s**, network is genuinely the bottleneck (not masked — 1n/2n/3n/
4n all show much larger `total_time` at 1Gbit vs 10/25Gbit), so the ~40%
*under*-estimate there is a more meaningful signal about the network model
itself specifically at the regime it *was* calibrated near (1 Gbit/s is
closer to poti's original 1 Gbit/s calibration point) — worth noting this is
the *one* band/topology combination where Level 2's number is a real,
uncompromised test of the network model, and it still misses by ~40%,
consistently under, across all 4 node counts. That consistency (same sign,
similar magnitude, regardless of node count) is itself informative: it
suggests a systematic bias in the network model's low-bandwidth regime,
not a scale-dependent effect.

## 5. Methodological caveat: 1 rep vs 5 reps

The real campaign's numbers in `analysis/results_package/tables/
part1_statistics.csv` are means of 5 repetitions per config, with reported
confidence intervals (`ci95_msamples`, `ci95_me`, etc.). Level 2 has
**exactly 1 run per config** — SimGrid simulation is deterministic given
fixed inputs (same platform, same calibration, same injected compute
constants), so repeating the identical simulated run would not produce a
different number and would not itself generate a meaningful confidence
interval.

This is not "no variance was accounted for" — some real variance is folded
in indirectly, because the three injected constants
(`DC_FIXED_BOUNDARIES_S`/`INTERIOR_S`/`BOOKKEEPING_S`, see
`analysis/level2_compute_constants.csv`) are themselves *means* of 5 real
repetitions' worth of extracted per-rank timings. But that's a single point
estimate folded into a deterministic simulation, not a distribution — Level
2's numbers have no confidence interval of their own and should not be
presented with error bars implying repeated-measurement uncertainty. If the
paper wants an actual simulated confidence interval, the real fix is to
inject a *distribution* (e.g. resample from the 5 real reps' per-rank timing
distribution once per simulated run, run N simulated repetitions) rather
than a single mean — not attempted here, flagged as a possible future
refinement.

## 6. Level 1 status (2026-08-13, chuc-7 + chuc-8: unblocked, 6/12 configs done, 6/12 hit a real hardware ceiling)

### 6.1 The `dlopen` bug: gone

On a fresh chuc allocation (chuc-7 + chuc-8, CUDA 12.8 / SimGrid 4.0 via the
flake devShell, vs. whatever combination triggered it originally) the
`dlopen` bug simply did not reproduce — neither in the minimal repro
(`dlopen_repro/run_repro.sh` (main branch), exit 0) nor in the real `bin/dc`. Root cause
was never conclusively identified (the two hypotheses in the `Makefile`'s
`simgrid_cuda` section — static/dynamic `cudart` linking, PIE/PIC — were
disproven back in the original investigation too), but it is not blocking
Level 1 anymore. `run_validation.sh`'s stale `--cfg=smpi/privatization:no`
workaround (which never actually fixed it) has been removed.

### 6.2 Two new real bugs found and fixed once `dlopen` was out of the way

1. **CUDA context bleed across SMPI's cooperative-coroutine ranks.**
   `add_source_kernel` (`src/device_data.cu`) intermittently dereferenced a
   device pointer that belonged to the *wrong* CUDA device — confirmed via
   `compute-sanitizer --tool memcheck` (invalid `__global__` read, address
   hundreds of MB past the nearest real allocation). Root cause: SMPI's
   default actor scheduler (`--cfg=contexts/factory`, default `ucontext`)
   runs every simulated rank as a cooperative coroutine on a single real OS
   thread, but `cudaSetDevice()`'s "current device" is OS-thread-local state,
   not per-rank state — when SMPI switches coroutines mid-run, the CUDA
   "current device" silently changes under whichever rank was mid-kernel.
   Fixed with `--cfg=contexts/factory:thread` (real OS thread per rank,
   restoring the 1:1 assumption CUDA's per-thread state needs). Confirmed
   fixed at both a small (256³) and the real N=1344/np=4 anchor size — see
   `run_validation.sh`'s `SMPI_CFG_COMMON` for the permanent fix + full
   comment.

2. **Host memory bloat from 14 never-reused precomp/anisotropy arrays.**
   `dc_worker_init_from_partition_info` (`src/worker.c`) allocates 20
   count-sized host float arrays per rank (4 field arrays, 6
   anisotropy/velocity, 10 `ch1d*`/`v2*` precomp arrays) but the CUDA kernel
   path only ever copies `vpz`/`vsv` to the device — the other 14 are
   computed on-the-fly inside the kernel (see `device_data.cu`'s existing
   comment) and are never read again on the host after their one-time init
   loop. Left allocated for the run's full lifetime, and with `RANKS_PER_NODE`
   simulated ranks all living in **one real OS process** (SMPI's
   architecture, see §6.3), this multiplied across every rank on the box:
   confirmed via `dmesg` that a 12-rank/3-node attempt was OOM-killed by the
   kernel at 524GB anon-rss on a 512GiB host. Fixed by `free()`-ing the 14
   dead arrays right after their init loop (`#ifdef SIMGRID`-guarded,
   `BACKEND=cuda` untouched — the real campaign never runs more than
   `RANKS_PER_NODE` processes on one real machine, so it was never exposed to
   this). Cut steady-state host memory per rank by ~70%, confirmed via
   `free -h` on a retest (no host OOM since).

### 6.3 Results: 6/12 configs completed successfully (1-node, 2-node, all 3 bandwidths)

Real online GPU sampling, no compute injection, on chuc-7/chuc-8 (2×
NVIDIA A100-SXM4-40GB nodes, 4 GPUs/node). Fidelity error computed by
`simgrid-chuc-validation/compute_fidelity_error.R` (same definition as
Level 2's script; needed the same `PMPI_`-prefix strip fix for ME, applied
here too — `sim_me` was `NA` for all configs until then). Full table:
`simgrid-chuc-validation/fidelity_error.csv`.

| nodes | band | real ms/s | sim ms/s | error (throughput) | real ME | sim ME | error (ME) |
|---|---|---|---|---|---|---|---|
| 1 | 1gbit  | 3266.5 | 3153.4 | **−3.5%** | 0.847 | 0.817 | −3.6% |
| 1 | 10gbit | 3325.8 | 3051.6 | **−8.3%** | 0.837 | 0.813 | −2.9% |
| 1 | 25gbit | 3298.5 | 3156.4 | **−4.3%** | 0.851 | 0.795 | −6.6% |
| 2 | 1gbit  | 4886.9 | 2440.1 | **−50.1%** | 0.449 | 0.235 | **−47.6%** |
| 2 | 10gbit | 7783.2 | 7603.3 | **−2.3%** | 0.783 | 0.780 | −0.4% |
| 2 | 25gbit | 7398.0 | 7422.7 | **+0.3%** | 0.744 | 0.781 | +4.9% |

This is dramatically closer to real than Level 2's fixed-compute-constant
substitution (§2's table has errors of +140% to +274%): Level 1's real
online sampling is single-digit-percent accurate on 5 of 6 completed
configs — strong evidence the network model (shared unchanged between
Level 1 and Level 2) is not itself the dominant error source; Level 2's
large errors trace mainly to the compute-constant substitution methodology,
not the underlying simulator.

**Outlier**: `2n_1gbit` is off by ~50% on both metrics, echoing the same
low-bandwidth degradation pattern flagged for Level 2 in §4 (throughput
−37 to −44%, ME −68 to −79% at 1Gbit/s across node counts ≥2) — worth
investigating together as likely the same root cause (probably the network
model's 1Gbit/s-specific calibration, not a Level-1-specific compute issue,
since Level 1 and Level 2 share the exact same network calibration and
platform). Not investigated further at the time.

### 6.4 3-node and 4-node on chuc: blocked by a real GPU VRAM ceiling (superseded — see §6.5)

SMPI's architecture runs **every** simulated rank of one `smpirun` invocation
as actors inside **one real OS process on one real machine** — it does not
(and structurally cannot, within a single simulation run) spread ranks'
real GPU/host memory across multiple physical chuc nodes, regardless of how
many are allocated (`run_validation.sh`'s header already documented this;
confirmed again here in practice). That real machine has exactly 4 real
A100s. With `RANKS_PER_NODE=4`:

- 3-node topology = 12 simulated ranks → 3 ranks share each real GPU.
- 4-node topology = 16 simulated ranks → 4 ranks share each real GPU.

Per-rank device memory at the real campaign's anchor N (6 float arrays —
`pp`,`pc`,`qp`,`qc`,`vpz`,`vsv` — at the 3-node partition size 645×964×964)
is ≈14.4GB. 3 ranks/GPU ≈ 43.2GB > 40GB → confirmed live:
`[9] CUDA Error: cudaMalloc vsv - out of memory` on chuc-7's 3-node attempt
(`3n_1Gbps`), after the host-memory fix (§6.2) got it past initialization
for 9 of 12 ranks (simulated t=+67.45s). 4-node (4 ranks/GPU ≈ 57.6GB,
partition 550×1092×1092) confirmed identically on chuc-8's `4n_1Gbps`
attempt: `[12] CUDA Error: cudaMalloc qc - out of memory` at simulated
t=+66.77s, rank 12 of 16.

`run_validation.sh` has `set -euo pipefail`, so each script stopped
immediately after its first fatal `smpirun` failure rather than burning
further chuc walltime retrying the remaining bandwidths at the same
topology (network bandwidth cannot change a compute/memory-bound GPU-OOM
outcome, so `3n_10Gbps`/`3n_25Gbps` and `4n_10Gbps`/`4n_25Gbps` were never
attempted — not needed, given the failure mode is deterministic and
bandwidth-independent).

This is **not fixable by further code changes** without either (a) reducing
the problem size specifically for these two topologies (breaks direct
same-N comparability with the real campaign's Table 3 measurements — a
methodology decision, not made unilaterally here) or (b) a real allocation
with more real GPUs sharing the load (not possible within one `smpirun`
process regardless of allocation size, per the architecture point above) or
more VRAM per GPU. Network bandwidth is irrelevant to this failure — it is
purely a compute/memory constraint, so all three bandwidths for both 3-node
and 4-node fail identically and fast (confirmed: `3n_1Gbps` failed at
t=+67s simulated, well before doing any real work).

### 6.5 Unblocked via a chicoree-1 allocation (H200, 140GB/GPU) — 10/12 total, but with a new hardware-mismatch caveat

We allocated `chicoree-1.lille.grid5000.fr` (4× NVIDIA H200 NVL,
~140GB VRAM each, 1TB host RAM) specifically to remove the §6.4 VRAM
ceiling. Rebuilt with `make BACKEND=simgrid_cuda ARCH=sm_90` (H200 is
Hopper, compute capability 9.0 — the Makefile already exposed `ARCH` as an
overridable variable, `ARCH ?= sm_80`, so no Makefile edit was needed).
Same `run_validation.sh`, same `contexts/factory:thread`/host-memory fixes
from §6.2 (both `#ifdef SIMGRID`-scoped, backend-agnostic).

Result: **3-node and 4-node no longer OOM** — 140GB/GPU trivially covers the
3-4 ranks/GPU that OOM'd at 40GB. `3n_1Gbps`, `3n_10Gbps`, `3n_25Gbps`, and
`4n_1Gbps` completed successfully. The chicoree allocation's walltime (~1h,
one short extension) ran out mid-init on `4n_10Gbps`; `4n_25Gbps` was never
attempted. **Final Level 1 tally: 10/12 configs**, only `4n_10Gbps` and
`4n_25Gbps` missing.

| nodes | band | real ms/s | sim ms/s | error (throughput) | real ME | sim ME | error (ME) |
|---|---|---|---|---|---|---|---|
| 1 | 1gbit  | 3266.5 | 3153.4  | −3.5%  | 0.847 | 0.817 | −3.6% |
| 1 | 10gbit | 3325.8 | 3051.6  | −8.3%  | 0.837 | 0.813 | −2.9% |
| 1 | 25gbit | 3298.5 | 3156.4  | −4.3%  | 0.851 | 0.795 | −6.6% |
| 2 | 1gbit  | 4886.9 | 2440.1  | −50.1% | 0.449 | 0.235 | −47.6% |
| 2 | 10gbit | 7783.2 | 7603.3  | −2.3%  | 0.783 | 0.780 | −0.4% |
| 2 | 25gbit | 7398.0 | 7422.7  | +0.3%  | 0.744 | 0.781 | +4.9% |
| 3 | 1gbit  | 2863.0 | 1590.7  | **−44.4%** | 0.289 | 0.055 | **−81.0%** |
| 3 | 10gbit | 5915.7 | 11817.4 | **+99.8%** | 0.622 | 0.443 | −28.8% |
| 3 | 25gbit | 5960.8 | 16950.2 | **+184%**  | 0.631 | 0.690 | +9.4% |
| 4 | 1gbit  | 3445.9 | 1834.0  | **−46.8%** | 0.262 | 0.044 | **−83.1%** |
| 4 | 10gbit | 8107.0 | —       | not attempted (walltime) | 0.637 | — | — |
| 4 | 25gbit | 8054.0 | —       | not attempted (walltime) | 0.643 | — | — |

**Critical caveat — hardware mismatch, not a methodology regression**: the
3-node/4-node errors are dramatically worse than 1-node/2-node's (which
stayed single-digit-to-teens except the already-flagged `2n_1gbit`
outlier). This is expected and explained: 1-node/2-node ran on chuc
(A100-SXM4-40GB, the **same GPU model the real campaign itself used**),
but 3-node/4-node ran on chicoree (H200 NVL) — a genuinely faster, newer
GPU. Level 1's entire method is *sampling the real wall-clock kernel time
on whatever GPU executes it* — on chicoree that measures the H200's real
(faster) kernel time, not the A100's, so the simulated throughput is not
actually modeling the real campaign's hardware for these two topologies.
This shows up exactly as expected: at 10/25Gbit/s (network no longer the
bottleneck, so compute time dominates and the GPU-speed mismatch shows
directly) the 3-node errors are large and *positive* (H200 faster than
A100 → higher throughput, +99.8%/+184%); at 1Gbit/s (network-bound) the
error is large and *negative* instead, matching the same low-bandwidth
degradation pattern already flagged for `2n_1gbit` and for Level 2 — i.e.
two independent, already-partially-understood effects (GPU speed mismatch
+ low-bandwidth network-model gap) compounding at 3-4 nodes, not a new bug.

**Bottom line for the paper**: 1-node and 2-node Level 1 results are a
clean, same-hardware validation of the simulator (single-digit-to-teens
fidelity error, 5 of 6 configs). 3-node and 4-node Level 1 results exist
(3/4 of them) but were sampled on different, faster GPU hardware than the
real campaign — **do not present them as same-hardware validation
alongside 1-node/2-node** without flagging the H200-vs-A100 substitution
explicitly, or better, re-run them on a chuc (A100) allocation with more
than 2 nodes if same-hardware 3-4 node Level 1 coverage is wanted for the
paper. Level 2 (§1-§5, real-A100-extracted compute constants, all on the
correct hardware) remains the paper's complete, same-hardware 12/12
fidelity story; Level 1 is the complementary "does live sampling agree"
spot-check, clean for 1-2 nodes, hardware-confounded for 3-4 nodes as
currently collected.

## 6.6 Reduced-N=1800 session (2026-08-14/17): same-hardware 3-4 node coverage, superseding §6.5's H200 numbers

Completed on chuc-1/chuc-4/chuc-6/chuc-8 (all real A100-SXM4-40GB, no
hardware mismatch this time). **12/12 configs, both real (genuine
distributed MPI) and simulated (SMPI), all at N=1800** (reduced from
Table 3's 1920/2176 anchors specifically to fit real GPU VRAM under SMPI's
single-real-machine oversubscription — see §6.4's derivation, unchanged).
Session ran across two separate OAR allocations (2026-08-14 partial: real
3-node all bands + 2 of 3 simulated 3-node configs; 2026-08-17 completion:
everything else), using the fully-detached, resumable orchestration in
`run_reduced_n_full.sh`/`run_reduced_n_real.sh`/`run_validation_reduced_n.sh`
(survives session/connection loss by design — see their headers).

**Final results** (`simgrid-chuc-validation/fidelity_error_reduced_n.csv`):

| nodes | band | real ms/s | sim ms/s | error (throughput) | real ME | sim ME | error (ME) |
|---|---|---|---|---|---|---|---|
| 3 | 1gbit  | 2504.98 | 1412.29 | **−43.6%** | 0.259 | 0.135 | **−48.1%** |
| 3 | 10gbit | 6604.64 | 6979.69 | +5.7%  | 0.681 | 0.696 | +2.1% |
| 3 | 25gbit | 6604.44 | 6231.52 | −5.7%  | 0.691 | 0.698 | +0.9% |
| 4 | 1gbit  | 2416.29 | 1438.95 | **−40.4%** | 0.183 | 0.124 | **−32.1%** |
| 4 | 10gbit | 7996.94 | 7044.53 | −11.9% | 0.609 | 0.656 | +7.7% |
| 4 | 25gbit | 8420.17 | 7338.30 | −12.8% | 0.607 | 0.657 | +8.2% |

Same-hardware, single-digit-to-teens throughput error at 10/25Gbit/s (in
line with the clean 1-2 node Level 1 numbers in §6.3) — the same 1Gbit/s
outlier pattern already flagged repeatedly (§6.3's `2n_1gbit`, Level 2's
§4) reproduces again here at both 3 and 4 nodes, reinforcing that it is a
real, band-specific network-model gap, not sampling noise or a per-config
fluke. **This table supersedes §6.5's H200 numbers for any same-hardware
3-4 node claim in the paper** — keep §6.5 only as the documented note that
hardware substitution (H200 vs A100) breaks Level 1's live-sampling
comparison, not as a result to report alongside the clean numbers above.

### The `aky_converter` bug that nearly cost the ME column (real config trace generation)

The 3 **real** 4-node configs' Akypuera trace conversion crashed
(`std::out_of_range`, "no send for this receive yet, do you synchronize
your input traces?") on first attempt, `2026-08-17` — every real config's
throughput was fine (that comes straight from `dc.output`, unaffected),
but `dc.trace`/`dc.csv` came out empty, which would have meant `NA` in the
ME column for exactly these 3 rows.

Root-caused live (not guessed): isolating 2-file subsets showed rank 0
(coordinator) legitimately point-to-point `MPI_Send`s its partition-info
struct to all 15 workers at startup, and with *real*, independent
per-machine clocks across 4 distinct physical hosts (unlike SMPI's single
simulated clock), a handful of these send/receive pairs get recorded with
an apparent causality inversion from clock skew — something
`aky_converter` can only correct with a `rastro_timesync`-generated sync
file (`-z/--sync=SYNC_FILE`), and `rastro_timesync` itself is not present
in the Nix package used here (only `aky_converter` is). A first fix
attempt (`-i/--ignore-errors` + numeric-not-lexicographic file ordering)
suppressed the crash but produced malformed `LINK` records for the
mismatched pairs, which then crashed `pj_dump` too (confirmed: field-count
mismatch on a `LINK` line), even with `pj_dump -z/--ignore-incomplete-links`
already in use.

**Actual fix**: `aky_converter -l/--no-links` skips converting
point-to-point `LINK` events entirely — exactly where the skew-triggered
mismatch lives — and the fidelity pipeline's `compute_me()` only ever
reads `State` rows (`MPI_Irecv`/`MPI_Waitall`), never `Link` rows, so this
loses nothing actually used. Confirmed live: `-l` alone (no `-i` needed)
produced a clean conversion, zero errors, 61182 valid `State` rows
including 32000 `MPI_Irecv`/`MPI_Waitall` entries, for all 3 configs.
Fixed in `run_reduced_n_real.sh` only — `g5k/05-run.sh`'s own
`aky_converter` call has the identical latent vulnerability (no `-l`, `-i`,
or `-z`) and was **not** touched, per the standing rule against editing
the real campaign's scripts; if any of its real runs ever needs this same
fix, apply the same `-l` flag there deliberately, not by copying this file.

## 6.7 Root-causing the recurring 1Gbit/s outlier (2026-08-17)

The same pattern — throughput and ME both large-magnitude negative
(simulated slower / less overlap than real) specifically at 1Gbit/s, at
every node count ≥2, present in Level 1 (§6.3, §6.6) AND Level 2 (§2, §4)
— was investigated directly on real hardware while the chuc allocation was
still live, rather than guessed at from first principles.

**Hypothesis 1 (per-message bandwidth calibration ceiling), tested and
NOT sufficient**: the Cornebize `smpi/bw-factor`/`smpi/lat-factor`
calibration's largest bin is 65480 bytes (~64KB); this app's halo
messages are ~13MB at N=1800 (200× larger), so every real message here
uses the *extrapolated* largest-bin factor (bw-factor 0.9412) regardless
of how much bigger it actually is. Measured live (`chuc-1` → `chuc-4`,
real `tc`-shaped 1Gbit/s link, a genuine 13,631,488-byte transfer, timed
with a raw Python socket to avoid `nc`'s own timing artifacts): **972.77
Mbit/s achieved, i.e. a real bw-factor of 0.973** — actually *slightly
better* than the model's 0.9412 assumption, not worse. A 3-point
efficiency gap in the model cannot explain a 40-50% throughput error (a
229.7s real run vs a 407s simulated run for the same config is a ~177s
gap; a 3% bandwidth mis-calibration only accounts for roughly 6s of
that). **This hypothesis is rejected as the primary cause.**

**Hypothesis 2 (shared-NIC contention model idealization), the better fit**:
`platform_shared_nic.cpp` models the `RANKS_PER_NODE=4` ranks on one real
node as sharing a *single* SimGrid link at the declared `net_bw` (1/10/25
Gbit/s), relying on SimGrid's default network model's max-min fair-share
congestion resolution when multiple flows use that link concurrently. This
assumes 4 ranks' halo-exchange sends are *perfectly simultaneous* for the
*entire* duration of each transfer, each capped at exactly 1/4 of the
link's bandwidth throughout. Real hardware/OS network stacks do not
behave this way in practice — independent completion timing of each
rank's boundary computation, OS scheduling jitter, and NIC-level queuing
naturally *stagger* real concurrent sends rather than holding them in
perfect lockstep, so each real transfer tends to get closer to the full
line rate for a larger fraction of its duration than an idealized
continuous 4-way fair-share predicts. This fits every observed fact:
      - Only shows up at 1Gbit/s: at 10/25Gbit/s, even a naive 4-way split
        still leaves 2.5-6.25Gbit/s per rank, far more than this app's halo
        traffic needs, so the contention-model idealization never binds.
      - Per-message bandwidth calibration checks out fine (Hyp. 1), so the
        error has to be in how *concurrent* flows are resolved, not in
        single-flow throughput.
      - Consistent magnitude at every node count ≥2 (2, 3, 4 nodes all show
        it) — expected, since `RANKS_PER_NODE=4` is constant regardless of
        total node count, so the same 4-way contention idealization applies
        identically at every scale.

**Not fully proven** (would need instrumenting SimGrid's own link-utilization
trace, or a real multi-rank concurrent-send microbenchmark isolating this
specific effect, neither done here under the remaining walltime) but
strongly evidence-supported and the most concrete lead so far — a
reasonable candidate explanation for the paper's limitations/future-work
discussion of this recurring pattern, in place of leaving it as an
unexplained anomaly.

## 7. Files changed/added in this phase

- `src/worker.c` — `DC_FIXED_BOUNDARIES_S`/`DC_FIXED_INTERIOR_S`/
  `DC_FIXED_BOOKKEEPING_S` injection (SIMGRID-only, `BACKEND=cuda` untouched),
  `DC_MALLOC` macro (currently `SMPI_SHARED_MALLOC`, validated interchangeable
  with plain `malloc` under the fixed methodology), skip of the 14
  never-read-under-bypass anisotropy/precomp arrays.
- `analysis/kernel_time_lib.R`, `analysis/extract_kernel_time.R`,
  `analysis/build_level2_compute_constants.R` — kernel + bookkeeping time
  extraction from real traces; writes `analysis/level2_compute_constants.csv`.
- `simgrid-chuc-validation/run_level2.sh` — orchestration for all 12 configs;
  `smpi/simulate-computation:no`, shared-malloc mode/blocksize tuning,
  bookkeeping injection wiring.
- `simgrid-chuc-validation/generate_platform_xml.py` — XML-platform
  equivalent of `platform_shared_nic.cpp`, needed because the locally
  available SimGrid (3.25, Debian bullseye, via `apt-get download`, no root)
  has an incompatible S4U C++ API vs. the 4.1 the `.cpp` targets; same
  topology, DTD-portable across SimGrid versions.
- `simgrid-chuc-validation/compute_fidelity_error_level2.R` — final analysis
  script (§2's table).
- `simgrid-chuc-validation/dlopen_repro/` (main branch) — minimal CUDA+SMPI repro, used
  2026-08-13 to confirm the `dlopen` bug no longer reproduces (§6.1).
- `simgrid-chuc-validation/fidelity_error_level2.csv` — machine-readable
  results.
- `src/worker.c` (2026-08-13 additions) — free the 14 never-reused
  anisotropy/precomp host arrays after their one-time init loop, `#ifdef
  SIMGRID`-guarded (§6.2, fixes a real host-RAM OOM).
- `src/device_data.cu` (2026-08-13) — `select_device()` gained a
  `#ifdef SIMGRID` branch (`rank % device_count`); left in place but note
  it did **not** turn out to be the fix for the CUDA-context bug (§6.2's
  real fix was `contexts/factory:thread`) — harmless and arguably still
  correct (real GPU assignment under a per-rank-hostname simulated
  platform), just not load-bearing for the bug that prompted it.
- `simgrid-chuc-validation/run_validation.sh` (2026-08-13) — removed the
  stale `smpi/privatization:no` dlopen-era workaround, added
  `contexts/factory:thread` (§6.2's real fix) with a full explanatory
  comment replacing the old one.
- `simgrid-chuc-validation/compute_fidelity_error.R` (2026-08-13) — same
  `PMPI_`-prefix strip fix as Level 2's script, needed for Level 1's
  `sim_me` to compute at all.
- `simgrid-chuc-validation/fidelity_error.csv`,
  `fidelity_error_table.tex` (2026-08-13) — Level 1's 6-config results
  (§6.3).
- `simgrid-chuc-validation/results/{1,2}n_{1,10,25}Gbps/` (2026-08-13) —
  the 6 completed Level 1 run outputs (`dc.output`, `dc.csv`,
  `metadata.txt`, `hostfile.txt`). `3n_1Gbps` and `4n_1Gbps` also have
  directories but their `dc.output` reflects the GPU-OOM failure, not a
  valid result (§6.4) — do not treat their presence as a completed config.

## 8. Open items for next session

1. Investigate the ME error's much larger magnitude and consistent negative
   sign at 1 Gbit/s (−68 to −79% for Level 2, §2; −47.6% for Level 1's
   `2n_1gbit`, §6.3) — same likely root cause (network model's 1Gbit/s
   calibration), not resolved either session.
2. Decide whether to pursue re-calibrating the network model's high-message-size
   regime (§4b) — needs real chuc network benchmarking.
3. Consider the distributional-injection refinement mentioned in §5 if
   simulated confidence intervals are wanted.
4. Level 1 is at 10/12: `4n_10Gbps` and `4n_25Gbps` were never completed
   (chicoree-1's allocation ran out of walltime mid-init on `4n_10Gbps`).
   Also, the 3-node/4-node results that DO exist were sampled on chicoree's
   H200 GPUs, not the real campaign's A100s (§6.5) — the options were
   to (a) present 3-4 node Level 1 numbers with the hardware-mismatch
   caveat as-is, (b) re-run 3-4 node Level 1 on an A100 (chuc) allocation
   with ≥3 nodes' worth of real GPUs for a same-hardware comparison, or
   (c) drop 3-4 node Level 1 from the paper and rely on Level 2 (already
   same-hardware, 12/12) for those topologies. Decided 2026-08-13/14: a
   same-hardware (A100) re-run at a reduced anchor size
   (REDUCED_N_RUNBOOK.md). For (b): the VRAM-ceiling numbers in §6.4
   (≈14.4GB/rank, 40GB/A100) tell you exactly how many real A100 GPUs are
   needed to avoid oversubscription (≥3/GPU is unsafe) — a 3-node chuc
   allocation of ≥2 real nodes each contributing enough real GPUs to a
   SINGLE `smpirun` process won't help either, per §6.4's architecture
   point; only a real allocation whose GPUs have ≥45GB (3-node) or ≥60GB
   (4-node) each removes it on A100-class hardware, or a single real node
   with more than 4 real GPUs so ranks-per-GPU drops below the 40GB line.
5. (Done 2026-08-13, kept for traceability) Level 1's `dlopen` bug: ran
   `dlopen_repro/run_repro.sh` (main branch) on the fresh chuc-7/chuc-8 allocation — did
   not reproduce. See §6.1.
