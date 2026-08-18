# Reduced-N (N=1800) session report — 2026-08-14

Consolidated report of the multi-allocation session run on 2026-08-14 to get
same-hardware (A100) real + simulated Level 1 data for 3-node and 4-node at
a reduced anchor N=1800, replacing the earlier hardware-mismatched chicoree/
H200 numbers (see LEVEL2_FINDINGS.md sec 6.5 for that background).

## 1. What got done

Three separate chuc allocations were used across the afternoon:

| Job | Hosts | Window | Outcome |
|---|---|---|---|
| 2187476 | chuc-1, chuc-2, chuc-8 (3) | 14:15–15:58 | Bootstrap + all 3 REAL 3-node configs completed |
| 2187587 | chuc-1, chuc-4, chuc-7 (3) | 16:05–16:56 | 2/6 SIM configs completed, 1 SIM config crashed (self-inflicted, see §3) |
| 2187011 | (4 hosts, chuc) | scheduled 17:05 | **Never started** — user fragged/cancelled the job (`FRAG_JOB_REQUEST` at 17:11:59, "Job killed by Leon directly") before it began running |

### Real 3-node (genuine distributed MPI, `BACKEND=cuda`, N=1800)

| band | msamples/s |
|---|---|
| 1gbit | 2504.98 |
| 10gbit | 6604.64 |
| 25gbit | 6604.44 |

All 3 completed cleanly. Along the way this session found and fixed a real
infrastructure bug: UCX (used by the original real-campaign recipe) does
not recognize chuc's production interface, a Linux bridge (`br0`) — it
only saw `lo` and the IB device, causing "Destination is unreachable" on
any multi-rank-per-node run. Fixed by switching to OpenMPI's native TCP
BTL (`--mca pml ob1 --mca btl tcp,self,sm --mca btl_tcp_if_include br0`),
which handles bridges with plain socket binding and has no such issue.
This app never needed UCX's GPU-aware transport anyway (halo exchange
already stages through host memory before MPI_Isend/Irecv). Already fixed
in `run_reduced_n_real.sh` for future use.

### Simulated (SMPI, `BACKEND=simgrid_cuda`, N=1800)

| nodes | band | msamples/s | fidelity error vs real 3-node |
|---|---|---|---|
| 3 | 1gbit | 1412.29 | **−43.6%** |
| 3 | 10gbit | 6979.69 | **+5.7%** |
| 3 | 25gbit | — | crashed (see §3), never retried before the 4-node job was cancelled |
| 4 | 1/10/25gbit | — | never attempted |

## 2. Real vs simulated fidelity at 3-node, N=1800

The 10gbit point (+5.7%) is in the same single-digit-error range as the
earlier same-hardware 1-2 node Level 1 results (LEVEL2_FINDINGS.md §6.3:
−8.3% to +0.3% for 5 of 6 configs). The 1gbit point (−43.6%) is a large
miss, but this matches an ALREADY-FLAGGED pattern, not a new problem:
every low-bandwidth config across this whole investigation shows outsized
error (Level 2 §4: −37% to −44% throughput / −68% to −79% ME at 1gbit
across node counts ≥2; Level 1 §6.3's `2n_1gbit`: −50.1%/−47.6%). The
network model's 1Gbit/s calibration regime is the common suspect across
all of these, still not root-caused (open item, see LEVEL2_FINDINGS.md §8
item 1).

## 3. What went wrong (self-inflicted, now fixed)

`3n_25Gbps`'s simulation crashed with `CUDA Error: cudaMalloc qp - out of
memory`. Root cause: a local-session reset (this happened repeatedly
during the day — see below) was believed to have killed the background
`run_validation_reduced_n.sh` process, so it was relaunched — but the
original process had actually survived (protected by `setsid`), so BOTH
copies ended up running `3n_25Gbps` concurrently, each independently
trying to allocate ~36GB/GPU, together exceeding the real 40GB VRAM. The
duplicate was killed as soon as this was noticed, but not before it
corrupted that specific config's run.

**Process-survival lesson learned and applied**: background remote work
launched via `ssh host 'cmd' &` from a local orchestrating shell does NOT
reliably survive the LOCAL session resetting, even with local
`nohup`/`setsid`/`disown` — if the underlying SSH transport drops, the
REMOTE command receives SIGHUP too unless it is ALSO wrapped in its own
`nohup ... & disown` on the remote host. This bit us 3 separate times
today. Not yet folded back into the actual scripts (`run_reduced_n_real.sh`
/ `run_validation_reduced_n.sh` still assume a stable orchestrating
session) — worth doing before the next multi-hour session if this kind of
local instability recurs.

## 4. What's still missing

- `3n_25Gbps` (SIM) — needs a clean retry, no known blocker.
- `4n_1Gbps`, `4n_10Gbps`, `4n_25Gbps` (SIM) — never attempted. Only need
  1 real chuc node each (SMPI single-real-process architecture).
- `4n_1gbit`, `4n_10gbit`, `4n_25gbit` (REAL) — never attempted, need 4
  real chuc nodes simultaneously (the 17:05 allocation that got cancelled).

7 of the original 12-config plan remain (1 sim retry + 3 sim + 3 real).

## 5. Can the 4-node numbers be predicted without running them?

Short answer: **a rough estimate is possible for the compute-bound bands,
genuinely uncertain for 1Gbit/s — and this is exactly the question the
simulator itself exists to answer better than hand extrapolation.** Not a
substitute for actually running it, but for planning purposes:

**10gbit / 25gbit (compute-bound)**: at 3-node, 10gbit and 25gbit already
give near-identical throughput (6604.64 vs 6604.44) — the network is not
the bottleneck at either bandwidth, compute is. Since N=1800 is FIXED
across node counts here (this is a strong-scaling comparison, not the
original campaign's weak-scaling design), going from 3 nodes (12 ranks,
topology 3×2×2) to 4 nodes (16 ranks, topology 4×2×2) shrinks each rank's
subdomain by 25%. In a compute-bound regime with no efficiency loss, that
would scale throughput up proportionally to rank count: 6604.6 ×
(16/12) ≈ **8806 msamples/s**. Real strong-scaling almost always falls
short of that (shrinking subdomains raise the surface-to-volume ratio,
so halo/communication overhead grows as a *fraction* of a shrinking
per-rank workload) — a more realistic band is roughly **7500–8500
msamples/s**, with the true number more likely toward the low end of that
range than the naive linear figure. Medium confidence.

**1gbit (network-bound)**: at 3-node, 1gbit already sits well below the
compute-bound plateau (2504.98 vs 6604.6, a 62% reduction from network
waiting) — network is clearly the bottleneck already. Adding a 4th node
generally increases total communication volume per iteration (more halo
faces exchanged in aggregate across a bigger Cartesian grid) at the SAME
fixed 1Gbit/s cap — this could make the network bottleneck *worse*, not
better, potentially leaving 4-node throughput similar to or even *below*
3-node's 2504.98, unlike the compute-bound bands where more nodes clearly
help. Low confidence either direction — genuinely could go either way by
a meaningful margin (rough guess: 2000–3000 range, wide uncertainty).

**Recommendation**: if another chuc allocation becomes available, running
just the 3 SIMULATED 4-node configs (cheap — one real GPU, no 4-node
allocation needed at all) would give a far more reliable prediction than
this hand extrapolation, and could be done before committing to a real
4-node allocation window. This is precisely the workflow Level 1's
simulator is meant to enable.
