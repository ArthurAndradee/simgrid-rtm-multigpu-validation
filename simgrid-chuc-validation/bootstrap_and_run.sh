#!/usr/bin/env bash
# bootstrap_and_run.sh — Nix bootstrap + run_validation.sh launcher for a
# freshly kadeploy'd chuc node. /nix is bind-mounted from ephemeral /tmp, so
# Nix must be reinstalled from scratch on every fresh deploy (confirmed
# 2026-08-12, jobs 2186228 and 2185769).
#
# IMPORTANT: this script runs as root (via `ssh root@chuc-N`), and root's
# $HOME is /root, NOT /home/aandrade -- root@chuc-N has no
# /root/ic/io-research/... directory. The repo lives under aandrade's NFS
# home, which IS shared/readable across all site nodes for both root@ and
# aandrade@. Do NOT use `cd ~/...` here (bug found live, job 2185769,
# 2026-08-12: silently failed with "No such file or directory" and wasted
# several irrecoverable minutes of a time-boxed allocation) -- always use the
# absolute path below.
#
# Usage (from frontend, nested ssh): scp this file to root@<host>:/tmp/,
# then: ssh root@<host> '/tmp/bootstrap_and_run.sh <node-subset>'
# e.g. '/tmp/bootstrap_and_run.sh 1,2'
set -euo pipefail
if [ ! -e /nix/var/nix/profiles/default ]; then
  mkdir -p /tmp/nix /nix
  mountpoint -q /nix || mount --bind /tmp/nix /nix
  sh <(curl -fsSL https://nixos.org/nix/install) --daemon --yes
fi
mkdir -p /etc/nix
grep -q "experimental-features" /etc/nix/nix.conf 2>/dev/null || echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
git config --global --add safe.directory "*"
NIXPROFILE=/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
source "$NIXPROFILE"
cd /home/aandrade/ic/io-research/distributed-cube-average
nix-shell simgrid-chuc-validation/shell.nix --run "bash ./simgrid-chuc-validation/run_validation.sh $1"
