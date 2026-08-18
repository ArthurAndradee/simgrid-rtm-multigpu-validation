#!/usr/bin/env bash
# scripts/01-bootstrap.sh — deploy + setup + build + sanity, in one shot.
# Thin wrapper over lib/{deploy,setup,build,validate}.sh, which are direct
# factorings of the validated g5k/01-deploy.sh, 02-setup.sh, 03-build.sh
# (byte-for-byte equivalent behavior — see g5k/lib/*.sh header comments).
#
# Usage: run inside an OAR job (oarsub -t deploy ... + kavlan), from the
# g5k/ directory:
#   ./scripts/01-bootstrap.sh
#
# Idempotent: safe to re-run (kadeploy will redeploy, Nix/setup steps are
# already idempotent per lib/setup.sh's own guards).
set -euo pipefail
cd "$(dirname "$0")/.."   # -> g5k/
source ./lib/core.sh
source ./conf/defaults.conf
source ./lib/deploy.sh
source ./lib/setup.sh
source ./lib/build.sh
source ./lib/run.sh
source ./lib/shape.sh
source ./lib/csv.sh
source ./lib/validate.sh
source ./lib/sciencelog.sh

log "=== 01-bootstrap: deploy ==="
deploy_run

log "=== 01-bootstrap: setup (SSH mesh, GPU census, Nix, nv-bridge, warmup) ==="
setup_run

log "=== 01-bootstrap: build ==="
build_run

log "=== 01-bootstrap: sanity checks ==="
validate_campaign_preflight
sciencelog_capture_versions

log "=== 01-bootstrap: OK ==="
log "Nós disponíveis: $(node_count) ($(nodes | paste -sd', '))"
log "Linhas do CSV compatíveis com esta alocação: $(csv_count_compatible_rows "$(node_count)") / $(csv_count_rows)"
log "Próximo passo: ./scripts/02-orchestrator.sh"
diary "Bootstrap completo. $(node_count) nós disponíveis. $(csv_count_compatible_rows "$(node_count)")/$(csv_count_rows) linhas do CSV executáveis nesta alocação."
