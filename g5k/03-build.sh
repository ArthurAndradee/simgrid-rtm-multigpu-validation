#!/usr/bin/env bash
# 03-build.sh — runs on the FRONTEND. Builds once, on the head node, inside
# the Nix shell. The binary lands in $PROJECT_DIR/bin/dc on the NFS home,
# which is shared by every node — no copying, no per-node builds.
#
# No `sed` on the Makefile: ARCH / CUDA_PATH are already parameters.
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh
require_nodes_file

: "${BACKEND:=cuda}"
: "${PROFILE:=akypuera}"
: "${ARCH:=sm_80}"     # NVIDIA A100

HEAD=$(head_node)
log "building on $HEAD (BACKEND=$BACKEND PROFILE=$PROFILE ARCH=$ARCH)"

node_script "$HEAD" <<EOF
set -e
source $NIX_PROFILE
cd $PROJECT_DIR
nix develop --command bash -c '
  set -e
  make clean
  make all BACKEND=$BACKEND PROFILE=$PROFILE ARCH=$ARCH
'
EOF

# NFS: visible from the frontend too
[ -x "$PROJECT_DIR/bin/dc" ] || die "build did not produce $PROJECT_DIR/bin/dc"
chmod 755 "$PROJECT_DIR/bin/dc"
log "build OK: $PROJECT_DIR/bin/dc"
