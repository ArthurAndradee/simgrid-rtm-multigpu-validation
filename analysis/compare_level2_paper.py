#!/usr/bin/env python3
"""Level 2 vs real chuc hardware for the 12 SSCAD-paper configurations.

Two readings per configuration:
  * throughput: global "*,time,throughput" line (what the paper's Table 4 /
    fidelity_error_level2.csv compared), real = median over reps;
  * in-loop time: max(last MPI_Waitall end) - min(first MPI_Irecv start)
    over ranks (the same window the ME metric uses).

Usage: compare_level2_paper.py <sim_results_subdir> [<sim_results_subdir> ...]
  e.g. poti_cornebize_SHARED poti_cornebize_SPLITDUPLEX
Writes <subdir>/comparison_vs_real.csv and prints a table.
"""
import csv, glob, os, re, statistics, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIM_BASE = os.path.join(ROOT, "simgrid-chuc-validation", "results_level2_paper")
REAL_BASE = os.path.join(ROOT, "g5k", "results")
ANCHOR_N = {1: 1344, 2: 1728, 3: 1920, 4: 2176}


def real_band(sim_band):
    """1Gbps->1gbit, 10Gbps->10gbit, 25Gbps->25gbit; effective-bandwidth
    labels (0.965Gbps, 11Gbps, 16Gbps) map to the shaped condition they
    were measured under."""
    v = float(re.match(r"([0-9.]+)", sim_band).group(1))
    return "1gbit" if v < 5 else ("10gbit" if v < 13 else "25gbit")


def global_line(path):
    try:
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("*,"):
                    _, t, thr = line.strip().split(",")[:3]
                    return float(t), float(thr)
    except OSError:
        pass
    return None


def loop_time(dc_csv):
    first, last = {}, {}
    try:
        with open(dc_csv, errors="replace") as f:
            for line in f:
                p = [x.strip() for x in line.split(",")]
                if len(p) < 8 or p[0] != "State":
                    continue
                name = p[7].replace("PMPI_", "MPI_")
                rank, start, end = p[1], float(p[3]), float(p[4])
                if name == "MPI_Irecv" and rank not in first:
                    first[rank] = start
                elif name == "MPI_Waitall":
                    last[rank] = end
    except OSError:
        return None
    if not first or not last:
        return None
    return max(last.values()) - min(first.values())


rows = []
for sub in sys.argv[1:]:
    for d in sorted(glob.glob(os.path.join(SIM_BASE, sub, "*n_*"))):
        m = re.match(r"(\d)n_(.+)$", os.path.basename(d))
        if not m:
            continue
        nodes, band = int(m.group(1)), m.group(2)
        sim = global_line(os.path.join(d, "dc.output"))
        if sim is None:
            continue
        sim_loop = loop_time(os.path.join(d, "dc.csv"))
        rdir = os.path.join(REAL_BASE, f"bench_{real_band(band)}_{nodes}n_{4*nodes}g_N{ANCHOR_N[nodes]}")
        reps = sorted(glob.glob(os.path.join(rdir, "rep*")))
        rg = [g for g in (global_line(os.path.join(r, "dc.output")) for r in reps) if g]
        rl = [l for l in (loop_time(os.path.join(r, "dc.csv")) for r in reps) if l]
        if not rg:
            continue
        real_thr = statistics.median(g[1] for g in rg)
        real_loop = statistics.median(rl) if rl else None
        rows.append(dict(
            sim_set=sub, nodes=nodes, band=band, real_condition=real_band(band), reps_real=len(rg),
            real_throughput=round(real_thr, 1), sim_throughput=round(sim[1], 1),
            throughput_err_pct=round(100 * (sim[1] - real_thr) / real_thr, 1),
            real_loop_s=round(real_loop, 2) if real_loop else "",
            sim_loop_s=round(sim_loop, 2) if sim_loop else "",
            loop_ratio_sim_over_real=round(sim_loop / real_loop, 3) if (sim_loop and real_loop) else ""))

if not rows:
    sys.exit("nenhum resultado comparável ainda")
for sub in sys.argv[1:]:
    g = [r for r in rows if r["sim_set"] == sub]
    if not g:
        continue
    out = os.path.join(SIM_BASE, sub, "comparison_vs_real.csv")
    with open(out, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(g[0].keys()))
        w.writeheader()
        w.writerows(g)
    print(f"\n== {sub} -> {out}")
    print(f"{'nós':>3} {'banda':>10} {'thr real':>9} {'thr sim':>9} {'erro thr':>9} {'laço real':>10} {'laço sim':>9} {'sim/real':>8}")
    for r in sorted(g, key=lambda r: (r["nodes"], float(re.match(r'[0-9.]+', r['band']).group(0)))):
        print(f"{r['nodes']:>3} {r['band']:>10} {r['real_throughput']:>9} {r['sim_throughput']:>9} "
              f"{r['throughput_err_pct']:>8}% {r['real_loop_s']:>9}s {r['sim_loop_s']:>8}s {r['loop_ratio_sim_over_real']:>8}")
