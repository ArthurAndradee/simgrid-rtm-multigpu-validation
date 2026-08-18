# shellcheck shell=bash
# ---------------------------------------------------------------------------
# build.sh — compile bin/dc via the Nix shell on the head node. Factored out
# of the validated g5k/03-build.sh (unchanged behavior; no Makefile sed'ing
# — ARCH/BACKEND/PROFILE are already Makefile parameters).
# ---------------------------------------------------------------------------

build_run() {
  require_nodes_file
  : "${BACKEND:=cuda}"
  : "${PROFILE:=akypuera}"
  : "${ARCH:=sm_80}"     # NVIDIA A100

  local head; head=$(head_node)
  log "building on $head (BACKEND=$BACKEND PROFILE=$PROFILE ARCH=$ARCH)"

  node_script "$head" <<EOF
set -e
source $NIX_PROFILE
cd $PROJECT_DIR
nix develop --command bash -c '
  set -e
  make clean
  make all BACKEND=$BACKEND PROFILE=$PROFILE ARCH=$ARCH
'
EOF

  [ -x "$PROJECT_DIR/bin/dc" ] || die "build did not produce $PROJECT_DIR/bin/dc"
  chmod 755 "$PROJECT_DIR/bin/dc"
  log "build OK: $PROJECT_DIR/bin/dc"
  diary "Build OK (BACKEND=$BACKEND PROFILE=$PROFILE ARCH=$ARCH), commit=$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo n/a)"
}
