#!/usr/bin/env python3
"""Level 2 simulation vs real chuc hardware, per strong-scaling topology.

Real:  g5k/results/<experiment_id>/rep*/dc.output  (global "*,time,throughput")
       -> median over reps
Sim:   simgrid-chuc-validation/results_level2_strongscale/<calib>/<id>/dc.output

Prints, per np: number of shapes, median signed throughput error, and the
Spearman rank correlation between sim and real throughput across shapes.
Writes the per-topology table next to the sim results.

Usage: compare_level2_strongscale.py [calib_dir_name=poti_cornebize_25Gbps]
"""
import csv, glob, os, re, statistics, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CALIB = sys.argv[1] if len(sys.argv) > 1 else "poti_cornebize_25Gbps"
SIM_DIR = os.path.join(ROOT, "simgrid-chuc-validation", "results_level2_strongscale", CALIB)
REAL_DIR = os.path.join(ROOT, "g5k", "results")


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


def ranks(v):
    order = sorted(range(len(v)), key=lambda i: v[i])
    r = [0.0] * len(v)
    i = 0
    while i < len(order):
        j = i
        while j + 1 < len(order) and v[order[j + 1]] == v[order[i]]:
            j += 1
        for k in range(i, j + 1):
            r[order[k]] = (i + j) / 2 + 1
        i = j + 1
    return r


def spearman(a, b):
    if len(a) < 3:
        return float("nan")
    ra, rb = ranks(a), ranks(b)
    ma, mb = statistics.mean(ra), statistics.mean(rb)
    num = sum((x - ma) * (y - mb) for x, y in zip(ra, rb))
    den = (sum((x - ma) ** 2 for x in ra) * sum((y - mb) ** 2 for y in rb)) ** 0.5
    return num / den if den else float("nan")


rows = []
for sim_out in sorted(glob.glob(os.path.join(SIM_DIR, "*", "dc.output"))):
    exp_id = os.path.basename(os.path.dirname(sim_out))
    sim = global_line(sim_out)
    if sim is None:
        continue
    real = [g for g in (global_line(p) for p in glob.glob(os.path.join(REAL_DIR, exp_id, "rep*", "dc.output"))) if g]
    if not real:
        continue
    np_ = int(re.search(r"_np(\d+)_", exp_id).group(1))
    dims = re.search(r"_np\d+_([0-9x]+)_N", exp_id).group(1)
    real_thr = statistics.median(r[1] for r in real)
    real_t = statistics.median(r[0] for r in real)
    rows.append(dict(experiment_id=exp_id, np=np_, dims=dims, reps_real=len(real),
                     real_time_s=real_t, sim_time_s=sim[0],
                     real_throughput=real_thr, sim_throughput=sim[1],
                     throughput_err_pct=100 * (sim[1] - real_thr) / real_thr))

out = os.path.join(SIM_DIR, "comparison_vs_real.csv")
with open(out, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    w.writeheader()
    w.writerows(rows)

print(f"{len(rows)} topologias comparadas -> {out}")
print(f"{'np':>3} {'formas':>6} {'erro_med%':>9} {'erro_min%':>9} {'erro_max%':>9} {'spearman':>8}")
for np_ in sorted({r["np"] for r in rows}):
    g = [r for r in rows if r["np"] == np_]
    e = [r["throughput_err_pct"] for r in g]
    rho = spearman([r["sim_throughput"] for r in g], [r["real_throughput"] for r in g])
    print(f"{np_:>3} {len(g):>6} {statistics.median(e):>9.1f} {min(e):>9.1f} {max(e):>9.1f} {rho:>8.2f}")
multi = [r for r in rows if r["np"] > 1]
if multi:
    rho_all = spearman([r["sim_throughput"] for r in multi], [r["real_throughput"] for r in multi])
    print(f"todas (np>1): spearman={rho_all:.2f}, erro mediano={statistics.median(r['throughput_err_pct'] for r in multi):.1f}%")
