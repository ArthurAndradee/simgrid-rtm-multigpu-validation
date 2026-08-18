#!/usr/bin/env bash
# 06-sweep.sh — runs on the FRONTEND. Bandwidth x problem-size sweep matching
# the SimGrid validation scenarios. Edit BANDWIDTHS / SIZES / RPN as needed.
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh
require_nodes_file

BANDWIDTHS=(${BANDWIDTHS:-1gbit 10gbit 25gbit})
SIZES=(${SIZES:-128 256 512})
RPN=${RPN:-1}              # 1 rank/host reproduces the TCC's SimGrid platform
ABSORPTION=${ABSORPTION:-2}

for bw in "${BANDWIDTHS[@]}"; do
  ./04-shape.sh "$bw"
  for size in "${SIZES[@]}"; do
    # same size convention as nix/scripts.nix (runSimGridExperiments)
    inner=$((size - 8 - 2 * ABSORPTION))
    ./05-run.sh --rpn "$RPN" --label "${bw}_${size}" -- \
      --size-x=$inner --size-y=$inner --size-z=$inner \
      --absorption=$ABSORPTION --dx=1e-1 --dy=1e-1 --dz=1e-1 \
      --dt=1e-6 --time-max=1e-4 \
      --output-file=./validation/predicted.dc
  done
done
./04-shape.sh off
log "sweep finished. See $PROJECT_DIR/results/"
