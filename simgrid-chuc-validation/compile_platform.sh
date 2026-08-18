#!/usr/bin/env bash
set -e
# Compiles platform_shared_nic.cpp — same two-artifact pattern as
# simgrid-config/compile_platform.sh (shared lib for smpirun to load, plus a
# standalone hostfile generator), kept as a separate script in this new
# directory rather than modifying the original.

if ! command -v pkg-config &> /dev/null; then
    echo "Error: pkg-config not found. Please enter the nix dev shell (nix develop)."
    exit 1
fi

SG_CFLAGS=$(pkg-config --cflags simgrid)
SG_LIBS=$(pkg-config --libs simgrid)

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "1. Compiling Shared Object (libplatform_shared_nic.so)..."
g++ -std=c++17 -shared -fPIC -o "$DIR/libplatform_shared_nic.so" "$DIR/platform_shared_nic.cpp" $SG_CFLAGS $SG_LIBS

echo "2. Compiling Generator Executable (generate_artifacts_shared_nic)..."
g++ -std=c++17 -o "$DIR/generate_artifacts_shared_nic" "$DIR/platform_shared_nic.cpp" $SG_CFLAGS $SG_LIBS

echo "Done. Required env vars: PLATFORM_NUM_NODES, PLATFORM_RANKS_PER_NODE,"
echo "PLATFORM_NET_BW, PLATFORM_NET_LAT, PLATFORM_HOSTFILE"
echo "(PLATFORM_INTRA_BW/PLATFORM_INTRA_LAT optional, default 200GBps/0.1us)."
