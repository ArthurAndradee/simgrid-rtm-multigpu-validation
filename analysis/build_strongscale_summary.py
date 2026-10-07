#!/usr/bin/env python3
"""Strong-scaling campaign (Idea 1) summary tables, from the real runs.

Inputs
  g5k/csv/strongscale_experiments.csv         101 planned partition shapes
  g5k/results/strongscale_*/rep*/dc.output    global "*,time,throughput" line
                                              + "Partition sizes" line
  analysis/masking_effectiveness_strongscale_all505.csv   ME per rep
                                              (analysis/masking_effectiveness.R)

Outputs
  analysis/strongscale_por_rep.csv        one row per (shape, rep)
  analysis/strongscale_por_topologia.csv  one row per shape: mean, sd and
                                          95% CI (Student t, n-1 df) of
                                          throughput, total time and ME, plus
                                          rank of the shape within its np

Throughput and total_time come from dc.output and include the one-time
costs outside the time loop (device init, data distribution, first
iteration); ME uses the in-loop window only (first MPI_Irecv to last
MPI_Waitall, as in analysis/masking_effectiveness.R).

Usage: python3 analysis/build_strongscale_summary.py   (from the repo root)
"""
import csv, glob, math, os, re, statistics

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLAN = os.path.join(ROOT, "g5k", "csv", "strongscale_experiments.csv")
RESULTS = os.path.join(ROOT, "g5k", "results")
ME_CSV = os.path.join(ROOT, "analysis", "masking_effectiveness_strongscale_all505.csv")
OUT_REP = os.path.join(ROOT, "analysis", "strongscale_por_rep.csv")
OUT_TOPO = os.path.join(ROOT, "analysis", "strongscale_por_topologia.csv")

# two-sided 95% Student t quantiles by degrees of freedom
T95 = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365, 8: 2.306, 9: 2.262}


def read_output(path):
    total = thr = part = None
    with open(path, errors="replace") as f:
        for line in f:
            if line.startswith("*,"):
                _, t, v = line.strip().split(",")[:3]
                total, thr = float(t), float(v)
            m = re.search(r"Partition sizes: (\d+) x (\d+) x (\d+)", line)
            if m:
                part = "x".join(m.groups())
    return total, thr, part


def stats(values):
    n = len(values)
    mean = statistics.mean(values)
    sd = statistics.stdev(values) if n > 1 else 0.0
    ci = T95.get(n - 1, 1.96) * sd / math.sqrt(n) if n > 1 else 0.0
    return mean, sd, ci


me = {}
with open(ME_CSV) as f:
    for r in csv.DictReader(f):
        me[(r["experiment_id"], int(r["rep"]))] = float(r["masking_effectiveness"])

plan = list(csv.DictReader(open(PLAN)))
rep_rows, topo_rows = [], []
for p in plan:
    exp_id, np_ = p["experiment_id"], int(p["np"])
    local = f'{p["local_x"]}x{p["local_y"]}x{p["local_z"]}'
    reps = []
    for d in sorted(glob.glob(os.path.join(RESULTS, exp_id, "rep*"))):
        rep = int(re.search(r"rep(\d+)$", d).group(1))
        total, thr, part = read_output(os.path.join(d, "dc.output"))
        if total is None:
            continue
        row = dict(experiment_id=exp_id, np=np_, dims=p["dims_str"], local_xyz=local,
                   partition_sizes_dc_output=part or "", rep=rep,
                   total_time_s=total, throughput_msamples_s=thr,
                   masking_effectiveness=me.get((exp_id, rep), ""))
        rep_rows.append(row)
        reps.append(row)
    if not reps:
        continue
    thr_m, thr_sd, thr_ci = stats([r["throughput_msamples_s"] for r in reps])
    t_m, t_sd, t_ci = stats([r["total_time_s"] for r in reps])
    mes = [r["masking_effectiveness"] for r in reps if r["masking_effectiveness"] != ""]
    me_m, me_sd, me_ci = stats(mes) if mes else ("", "", "")
    topo_rows.append(dict(experiment_id=exp_id, np=np_, dims=p["dims_str"], local_xyz=local,
                          reps=len(reps),
                          throughput_mean=thr_m, throughput_sd=thr_sd, throughput_ci95=thr_ci,
                          total_time_mean_s=t_m, total_time_ci95_s=t_ci,
                          me_mean=me_m, me_sd=me_sd, me_ci95=me_ci))

# rank of each shape inside its np (1 = highest throughput), and the gap to
# the best shape of the same np
for np_ in {r["np"] for r in topo_rows}:
    group = sorted((r for r in topo_rows if r["np"] == np_), key=lambda r: -r["throughput_mean"])
    best = group[0]["throughput_mean"]
    for i, r in enumerate(group, 1):
        r["rank_in_np"] = i
        r["shapes_in_np"] = len(group)
        r["throughput_vs_best_in_np"] = r["throughput_mean"] / best

base = next(r["throughput_mean"] for r in topo_rows if r["np"] == 1)
for r in topo_rows:
    r["parallel_efficiency_vs_np1"] = r["throughput_mean"] / (base * r["np"])

for path, rows in ((OUT_REP, rep_rows), (OUT_TOPO, topo_rows)):
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(sorted(rows, key=lambda r: (r["np"], r["experiment_id"], r.get("rep", 0))))

mismatch = [r for r in rep_rows if r["partition_sizes_dc_output"] and r["partition_sizes_dc_output"] != r["local_xyz"]]
print(f"{len(rep_rows)} reps, {len(topo_rows)} topologias -> {OUT_REP}, {OUT_TOPO}")
print(f"reps cujo 'Partition sizes' difere do plano: {len(mismatch)}")
print(f"{'np':>3} {'formas':>6} {'melhor (MS/s)':>14} {'pior (MS/s)':>12} {'melhor/pior':>11} {'ME min':>7} {'ME max':>7}  melhor forma")
for np_ in sorted({r["np"] for r in topo_rows}):
    g = sorted((r for r in topo_rows if r["np"] == np_), key=lambda r: -r["throughput_mean"])
    mes = [r["me_mean"] for r in g if r["me_mean"] != ""]
    print(f"{np_:>3} {len(g):>6} {g[0]['throughput_mean']:>14.0f} {g[-1]['throughput_mean']:>12.0f} "
          f"{g[0]['throughput_mean'] / g[-1]['throughput_mean']:>11.2f} "
          f"{(min(mes) if mes else float('nan')):>7.3f} {(max(mes) if mes else float('nan')):>7.3f}  {g[0]['dims']}")
