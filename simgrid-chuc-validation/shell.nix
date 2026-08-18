{pkgs ? import <nixpkgs> {config = {allowUnfree = true;};}}:
# Minimal dev shell for simgrid-chuc-validation/, deliberately NOT the
# project's full flake devShell (see flake.nix): that one also pulls in
# vite, pandoc, clang-tools, akypuera, and a full R environment
# (tidyverse/plotly/patchwork/...), none of which this validation needs --
# akypuera specifically is unnecessary because SMPI's own --cfg=tracing
# writes dc.trace directly in Paje format, no aky_converter step involved
# (see run_validation.sh's postProcessLogic comment). Cutting this down
# matters under a tight walltime: less to fetch/build before anything can
# run. compute_fidelity_error.R runs separately via the `r-analysis` conda
# env already validated working (see project conversation log), not through
# this shell at all.
let
  # pajeng is NOT a nixpkgs package -- it's this project's own derivation
  # (built from github.com/schnorr/pajeng), same one flake.nix wires in.
  pajeng = import ../nix/pajeng.nix {inherit pkgs;};
in
pkgs.mkShell {
  buildInputs = [
    pkgs.cudatoolkit
    pkgs.openmpi
    pkgs.simgrid
    pajeng
    pkgs.pkg-config
    pkgs.gcc
  ];
  shellHook = ''
    export CUDA_PATH=${pkgs.cudatoolkit}
  '';
}
