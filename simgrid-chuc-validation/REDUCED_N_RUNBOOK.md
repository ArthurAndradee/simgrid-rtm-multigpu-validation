# Reduced-N runbook — 3-node and 4-node Level 1, real A100 reference (2026-08-14)

Plan agreed on 2026-08-13/14: replace the hardware-mismatched
chicoree/H200 3-4 node numbers with same-hardware (A100) results, at a
REDUCED anchor size that fits real GPU VRAM, PLUS a genuinely new real
(non-simulated) reference run at that same N for a valid comparison.
**12 total configs**: 6 REAL + 6 SIMULATED (3n+4n × 1/10/25gbit each).

**Allocation obtained**: 4 chuc nodes, 2026-08-14 17:05-18:55 (110 min),
**standard job, NOT `-t deploy`** (confirmed via `oarstat -f`). Considered
resubmitting with `-t deploy` (would reuse the real campaign's own,
already-validated `g5k/01-05*.sh` pipeline) but decided against it: kadeploy3
+ `02-setup.sh`'s SSH mesh/Nix warmup adds ~25-35 min of fixed overhead
before any actual experiment runs, which doesn't fit comfortably alongside
12 configs in a 110 min budget. Instead: a self-contained script
(`run_reduced_n_real.sh`) that reimplements the same validated recipe
(UCX/pml_ucx_tls fix, driver bridge, mpirun flags — read from
`g5k/lib/run.sh`/`05-run.sh` for reference, not modified) but bootstraps
via `sudo-g5k` + manual Nix install (same pattern validated 3x already this
session on chuc-7/chuc-8/chicoree-1) and shapes bandwidth on the production
interface instead of a kavlan-isolated one. The one genuinely untested
piece — real cross-node MPI without a deploy job's SSH mesh setup — is
checked with a cheap smoke test (§2) before committing walltime to it.

**Time budget, with the parallelization in §3-4**: bootstrap ~15 min, smoke
test <1 min, real 4-node (all 3 bands, sequential, needs all 4 real GPUs)
~15 min, then real 3-node (3 bands) run CONCURRENTLY with all 6 simulated
configs on the excluded 4th host (~15-18 min, since sim only needs 1 real
node and the excluded host isn't touched by the 3-node real run — no GPU
contention). **Estimated total ~45-50 min of the 110 available**, leaving
~60 min of margin. `run_reduced_n_full.sh` runs all of this in one command,
already in the right order so a walltime cutoff preserves whatever
completed first (real 4n > [real 3n + sim] in priority).

## 0. Why N=1800 (not the original 1920/2176)

Derivation and exact numbers: see `/tmp/calc_reduced_n.py` from the prior
session (reproduce if needed — not preserved on disk, straightforward to
redo: 6 float device arrays/rank × 4 bytes, empirically-confirmed
`MPI_Dims_create` topologies `(3,2,2)` for 3-node / `(4,2,2)` for 4-node,
worst-case local partition size including the remainder-absorbing last
worker in each dimension, target ≤85% of 40GiB per real A100 divided by
ranks-sharing-that-GPU).

| nodes | ranks/GPU (real A100, 1 real chuc node) | N=1800 mem/rank | mem/GPU | headroom |
|---|---|---|---|---|
| 3 | 3 | 11.89 GB | 35.66 GB | 4.3 GB (CUDA ctx/driver/MPI buffers) |
| 4 | 4 | 8.94 GB  | 35.77 GB | 4.2 GB |

`cuda_size` (the `--size-x/y/z` CLI arg) = `1800 - 2*STENCIL - 2*ABSORPTION`
= `1800 - 12` = **1788**.

**This N is intentionally different from Table 3's anchors (1920/2176) —
do not compare reduced-N results against Table 3 directly.** The whole
point is a same-N comparison between the reduced-N simulation (§1) and a
reduced-N REAL run (§2/§3).

## 1. The 4 scripts

- **`run_validation_reduced_n.sh`** — Level 1 SIMGRID simulation at N=1800,
  3n+4n × all 3 bands (6 configs). Same machinery as the original
  `run_validation.sh` (`contexts/factory:thread`, shared-NIC platform,
  driver bridge), only the anchor N differs. Builds into `BUILDDIR=bin_sim`
  (NOT the default `bin/`) so it never clobbers the real build below, even
  if they happen to touch the same checkout around the same time.
  Needs only 1 real chuc node.
- **`run_reduced_n_real.sh`** — the REAL (genuine distributed MPI,
  `BACKEND=cuda ARCH=sm_80`) counterpart, 3n+4n × all 3 bands (6 configs),
  at the same N=1800. Builds into the default `bin/`. Has 3 modes
  (`MODE=bootstrap`, `MODE=smoke`, `MODE=run` — see its header) so the
  expensive setup (Nix bootstrap on all 4 nodes + build + devShell warmup
  on every node) happens once and is idempotent.
- **`run_reduced_n_full.sh`** — orchestrates both, in the time-optimized
  order described above. **This is the one command to run tomorrow.**
- **`REDUCED_N_RUNBOOK.md`** — this file.

## 2. Running it (one command)

From the HEAD node of the 4-chuc allocation, as `aandrade`, inside the OAR
job (`$OAR_NODE_FILE` set) — or export `HOSTS_OVERRIDE="host1 host2 host3
host4"` manually if running from the frontend instead:

```bash
cd ~/ic/io-research/distributed-cube-average
bash simgrid-chuc-validation/run_reduced_n_full.sh
```

This runs, in order (see script header for the full time-budget rationale):
1. Bootstrap: Nix on all 4 nodes, build `bin/dc` (BACKEND=cuda) on the
   head, warm up the flake devShell on the other 3 (needed so mpirun's
   remote daemon launch finds identical `/nix/store` paths on every node —
   `/nix` is a per-node local bind-mount, not NFS-shared).
2. Smoke test: 2-rank real cross-node MPI hello-world. **If this fails,
   the script stops immediately** rather than burning walltime on 6 real
   configs likely to fail the same way — read the error, fix it (SSH mesh?
   UCX transport?), then just re-run the same command (bootstrap is
   idempotent, skips already-done work).
3. Real 4-node, all 3 bands (needs all 4 real GPUs, sequential).
4. Real 3-node (3 of the 4 hosts) **in parallel with** all 6 simulated
   configs (confined to the 4th, excluded host) — safe because neither
   touches the other's physical GPUs.

Both underlying scripts are independently resumable (skip-if-already-has-
valid-output), so if walltime runs out, re-running the same command picks
up where it left off.

Results:
- **Real**: `simgrid-chuc-validation/results_reduced_n_real/<n>n_<band>/`
- **Simulated**: `simgrid-chuc-validation/results_reduced_n/<n>n_<band>Gbps/`

**Do not confuse the two trees** — same N, different nature (genuine MPI
vs SMPI), that is the whole point of the comparison.

## 3. After the session

- Extract `msamples_per_s` (the `*` row) and ME from each real
  `dc.output`/`dc.csv` pair in `results_reduced_n_real/` (same method as
  `analysis/masking_effectiveness.R` / `compute_fidelity_error.R`'s
  `compute_me()` — reuse, don't reimplement).
- Compute fidelity error against the matching config in
  `results_reduced_n/` (simulated), same formula as
  `compute_fidelity_error.R` (100×(sim−real)/real) — ideally by adapting
  that script (or a copy) to read from `results_reduced_n{,_real}/`
  instead of `results/`.
- Update `simgrid-chuc-validation/LEVEL2_FINDINGS.md` §6.5: replace the
  H200 table with the new same-hardware (A100) N=1800 numbers (12/12, if
  the full session completes), keep the H200 numbers too but clearly
  labeled as the earlier hardware-mismatched data point, not the primary
  result.
- If the session only completed a subset (walltime ran out), the priority
  order in the script header tells you exactly what's missing and why —
  document that honestly rather than silently treating a partial run as
  complete.
- Note this reduced-N (1800) result is still NOT the same anchor as
  Table 3's original 3-4 node sizes (1920/2176) — it validates the
  simulator at a different, smaller problem size for these two topologies,
  not the exact published weak-scaling point. Keep that distinction clear
  in the write-up.
