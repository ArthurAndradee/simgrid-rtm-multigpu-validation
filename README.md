# SimGrid RTM Multi-GPU Validation

Experimental artifact for **"Experimental Validation of SimGrid Predictions
for RTM Applications in Multi-Node Multi-GPU Environments"** (Arthur
Andrade da Silva, Vinícius Daniel Spadotto, Cristiano Alex Künas, Lucas
Mello Schnorr, Phillipe Olivier Alexandre Navaux — Institute of
Informatics, UFRGS).

> **Branch `campanha-2026-10`**: adds the post-paper data (October 2026): the
> complete strong-scaling campaign, new Level 2 simulations and network
> measurements on chuc, with the paper's figures and tables rebuilt on them.
> Start at [`campanha-2026-10/README.md`](campanha-2026-10/README.md) (in Portuguese).
> The `main` branch is the paper's artifact, unchanged.

## What this is

A SimGrid/SMPI model of Fletcher — an anisotropic reverse time migration
(RTM) application — was calibrated on single-GPU-per-node hardware and a
1 Gbit/s network, and projected that higher bandwidths would raise the
fraction of time spent computing. This work determines the **validity
envelope** of that prediction: we run Fletcher's real CUDA/MPI backend on
Grid'5000's `chuc` cluster (four NVIDIA A100 GPUs per node) across **one to
four nodes** and bandwidths of **1, 10, and 25 Gbit/s**, and confront the
real measurements against the equivalent SimGrid predictions at three
levels of fidelity.

**Main result**: the predicted trend (more bandwidth → more masking) holds
qualitatively, but its quantitative accuracy degrades with scale — the
spread in effective overlap (Masking Effectiveness) across bandwidths grows
from 1.3 percentage points at one node to 38.2 at four. The prediction's
*direction* extrapolates to new hardware generations; its *magnitude*
needs direct measurement.

This repository contains everything needed to understand, audit, and
reproduce that result: the application source, the real-hardware campaign
orchestration, the three simulation methodologies compared against it, the
analysis pipeline that turns raw traces into the paper's tables and
figures, and the engineering log kept during the real campaign.

## Repository structure

```
├── src/, include/, Makefile   Fletcher's CUDA+MPI/OpenMP/SMPI implementation
│                              (multiple BACKEND targets: cuda, openmp,
│                              simgrid, simgrid_cuda — see Makefile)
├── flake.nix, nix/            Nix flake: pins the exact toolchain (CUDA
│                              12.8, OpenMPI 5.0.9, SimGrid, Akypuera/
│                              pajeng tracing) used for every run below
│
├── g5k/                       REAL hardware campaign (Grid'5000, chuc
│   ├── 00-reserve.md            cluster, A100 GPUs)
│   ├── 01-deploy.sh .. 06-sweep.sh   numbered pipeline stages (deploy →
│   │                            setup → build → bandwidth-shape → run →
│   │                            full sweep) — see 00-reserve.md to start
│   ├── lib/                    shared shell functions (UCX fix, driver
│   │                            bridge, checkpoint/resume, provenance)
│   ├── conf/defaults.conf      campaign-wide physics/domain constants
│   ├── csv/experimentos.csv    the experiment design (weak-scaling anchor
│   │                            sizes × node counts × bandwidths × reps)
│   ├── logs/                   engineering diary (diario_de_bordo.md) and
│   │                            toolchain versions, kept DURING the real
│   │                            campaign — the paper's "provenance tracking"
│   │                            contribution (design notes: main branch)
│   └── results/                per-(config,rep) real run outputs: final
│                                stats (dc.output) + provenance
│                                (metadata.txt, hostfile.mpi) for every
│                                completed repetition. Raw per-rank trace
│                                files (dc.csv/dc.trace/rastro-*.rst) are
│                                NOT included here (regenerable, large) —
│                                see "Reproducing figures" below.
│
├── simgrid-chuc-validation/   The THREE simulation methodologies, each
│   ├── run_validation.sh        compared against the g5k/ real campaign:
│   ├── run_level2.sh            1. run_validation.sh — real online GPU
│   ├── run_validation_reduced_n.sh   kernel sampling under SMPI ("Level 1")
│   ├── run_reduced_n_real.sh    2. run_level2.sh — real A100 compute
│   │                               constants (extracted from g5k/results)
│   │                               substituted for live sampling ("Level 2")
│   │                            3. run_reduced_n_*.sh — same-N real vs.
│   │                               simulated pair at a reduced problem
│   │                               size, specifically for 3-4 node
│   │                               topologies where Level 1's real online
│   │                               sampling needs more GPU VRAM than 2
│   │                               chuc nodes provide (see
│   │                               REDUCED_N_RUNBOOK.md)
│   ├── compute_fidelity_error*.R    fidelity-error computation (sim vs
│   │                                 real, per (nodes,band) config)
│   ├── LEVEL2_FINDINGS.md       full narrative: methodology, every bug
│   │                            found and fixed, every number, every
│   │                            caveat — written to draft the paper from
│   ├── platform_shared_nic.cpp  SimGrid S4U platform description (shared-
│   │                            NIC network model matching chuc's topology)
│   └── results*/                per-config simulated (and, for the
│                                 reduced-N variant, real) run outputs
│
├── analysis/                  Turns raw g5k/ + simgrid-chuc-validation/
│   ├── aggregate_stats.R        outputs into the paper's tables and
│   ├── masking_effectiveness.R  figures. results_package/ is the final,
│   ├── throughput_raw.csv       ready-to-cite output (tables/, figures/).
│   └── results_package/
│       ├── build_*.R            one script per figure/table family
│       ├── tables/               TABELA_*.csv / part*.csv — every number
│       │                         reported in the paper
│       └── figures/              fig1..fig4 (PDF+PNG, EN+PT), including
│                                  the fig1_sim_vs_real_v*.pdf exploratory
│                                  variants comparing real and simulated
│                                  masking timelines panel-by-panel
│
├── validation/                 R scripts comparing simulated vs. real
│                                results (independent of the fidelity-error
│                                scripts above; earlier/simpler check)
│
└── papers/2026_chuc_gpu_validation/main.tex   the paper itself, with the
                                figures it cites copied alongside it
```

## Provenance and attribution

`src/`, `include/`, and `Makefile` implement Fletcher's domain
decomposition, CUDA kernels, and MPI/SMPI backends. This code originates
from Vinícius Daniel Spadotto's prior work
([Dannful/distributed-cube-average](https://github.com/Dannful/distributed-cube-average)),
cited in the paper as `spadotto2026sbacpad` / `spadotto2026tcc` /
`spadotto2026carla`. Spadotto is a co-author of the paper this repository
accompanies, and the paper commits explicitly to releasing this
experimental framework alongside it. **This repository was created from
scratch** — a fresh Git history with no fork, clone, or imported commits
from the original repository — and contains a curated snapshot of the code
needed to run and understand the experiments, plus all the campaign
orchestration, simulation harnesses, and analysis pipeline written
specifically for this paper.

## Dependencies

Everything (application, SimGrid, tracing tools, R analysis environment)
is pinned by the Nix flake at the repository root:

```bash
nix develop        # drops you into a shell with the full toolchain:
                    # CUDA 12.8, OpenMPI 5.0.9, SimGrid, Akypuera/pajeng
```

The R analysis scripts (`analysis/`, `simgrid-chuc-validation/*.R`) need
the `tidyverse` package; run them from a shell with R + tidyverse
available (e.g. `conda activate r-analysis` if using conda, or any R
environment with `install.packages("tidyverse")`).

## Building the application

```bash
make all BACKEND=cuda ARCH=sm_80 PROFILE=akypuera   # real GPU campaign
make all BACKEND=simgrid_cuda ARCH=sm_80            # SMPI + real online GPU sampling (Level 1)
make all BACKEND=simgrid                            # SMPI + CPU/OpenMP (Level 2, no GPU needed)
```

`BACKEND`, `ARCH`, and `PROFILE` are plain Makefile variables — see the
Makefile header for the full list and what each combination needs.

## Running the experiments

### Real hardware campaign (needs a Grid'5000 `chuc` allocation)

Start at [`g5k/00-reserve.md`](g5k/00-reserve.md) for the OAR reservation
command, then run the numbered scripts in order (`01-deploy.sh` through
`06-sweep.sh`); each stage's header comment documents what it does and
what it needs. The full design (weak-scaling anchor sizes per node count,
bandwidths, repetitions) is in [`g5k/csv/experimentos.csv`](g5k/csv/experimentos.csv)
and [`g5k/conf/defaults.conf`](g5k/conf/defaults.conf).

### Simulation (no cluster needed for Level 2; needs 1+ real A100 nodes for Level 1)

```bash
cd simgrid-chuc-validation
nix develop --command bash run_level2.sh            # Level 2: no GPU needed
nix develop --command bash run_validation.sh 1,2     # Level 1: needs real A100s
```

See [`simgrid-chuc-validation/RUNBOOK.md`](simgrid-chuc-validation/RUNBOOK.md),
[`REDUCED_N_RUNBOOK.md`](simgrid-chuc-validation/REDUCED_N_RUNBOOK.md), and
[`LEVEL2_FINDINGS.md`](simgrid-chuc-validation/LEVEL2_FINDINGS.md) for the
full methodology, every fidelity-affecting bug found during this work (and
its fix), and the complete numeric results with discussion.

## Reproducing the paper's tables and figures

Aggregated CSVs for every table/figure are already included under
`analysis/throughput_raw.csv`, `analysis/results_package/tables/`, and
`simgrid-chuc-validation/*fidelity_error*.csv` — you do not need to re-run
the campaign to regenerate the tables and figures themselves:

```bash
cd analysis/results_package
Rscript build_results_package.R   # tables
Rscript build_figures.R           # fig2, fig3, fig4
Rscript build_load_charts.R       # fig1 (real-only, published version)
```

The `fig1_sim_vs_real_v*.pdf` exploratory variants (real vs. simulated
masking timeline, side by side) are built by:

```bash
Rscript build_sim_vs_real_timeline.R
```

**Note on raw traces**: figure 1's per-rank timeline needs the raw
per-rank `dc.csv`/`dc.trace` trace files, which are not included in this
repository (large, regenerable). Re-running the corresponding stage in
`g5k/05-run.sh` or the `simgrid-chuc-validation/run_*.sh` scripts
regenerates them in the exact directory layout the figure scripts expect.
Every other table and figure in the paper is reproducible directly from
the aggregated CSVs already included here.

## Key results

| Comparison | Node counts | Fidelity error (throughput) | Notes |
|---|---|---|---|
| Level 1 (real online GPU sampling, same A100 hardware) | 1-2 | −8.3% to +0.3% | Clean, single-digit error |
| Level 1, reduced-N same-hardware pair | 3-4 | −14.2% to +5.7% | See `REDUCED_N_RUNBOOK.md` |
| Level 2 (real compute constant substituted) | 1-4 | −44% to +274% | Large at 10/25 Gbit/s — compute-substitution artifact, not a network-model failure (see `LEVEL2_FINDINGS.md` §4) |

The 1 Gbit/s band consistently shows the largest, most systematic
divergence across every methodology and node count — see the paper's
Table 5 and `LEVEL2_FINDINGS.md` for the full discussion.

## License

MIT — see [`LICENSE`](LICENSE). See [`CITATION.cff`](CITATION.cff) for how
to cite this work.
