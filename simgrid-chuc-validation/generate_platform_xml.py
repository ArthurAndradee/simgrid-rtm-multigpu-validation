#!/usr/bin/env python3
"""generate_platform_xml.py — XML-format equivalent of platform_shared_nic.cpp.

WHY THIS EXISTS (2026-08-12): platform_shared_nic.cpp uses the SimGrid 4.1
S4U C++ API (add_router/add_host/add_link/seal, as pinned by this project's
Nix flake). The only SimGrid available on this machine without a chuc
allocation is 3.25 (Debian bullseye's `libsimgrid-dev`), whose S4U C++ API
is meaningfully different (no add_router/add_host/add_link on NetZone, no
seal()) -- porting the C++ file to the 3.25 API would mean Level 2 runs on a
literally different simulator ENGINE VERSION than Level 1 will eventually
use, which is a bigger, less controlled difference than the one thing Level
2 is supposed to isolate (compute only). The XML platform format's DTD is
stable across SimGrid's 3.x-4.x line (host/link/router/route elements
unchanged), so this script emits the IDENTICAL topology as
platform_shared_nic.cpp's load_platform(), as a static XML file smpirun can
load with `-platform file.xml` on EITHER SimGrid version -- confirmed
against the same --cfg=smpi/os:... Cornebize calibration flags in a local
smoke test with the 3.25 binary.

Topology, per node i (0..num_nodes-1):
  host-{i*ranks_per_node+j}  --intra_link(fast)--  node_switch_i
  node_switch_i              --node_link_i(shaped)--  global_switch

routing="Floyd" (matching the C++'s add_netzone_floyd): only the direct
edges above are declared; multi-hop host-to-host routes are computed
automatically via shortest path, identical to the C++ version's behavior.

Usage: PLATFORM_NUM_NODES=... PLATFORM_RANKS_PER_NODE=... PLATFORM_NET_BW=...
       PLATFORM_NET_LAT=... PLATFORM_HOSTFILE=... [PLATFORM_INTRA_BW=...]
       [PLATFORM_INTRA_LAT=...] [PLATFORM_XML_OUT=...]
       python3 generate_platform_xml.py
"""
import os
import sys


def require_env(name):
    val = os.environ.get(name)
    if val is None:
        sys.stderr.write(f"Error: Environment variable '{name}' is required but not set.\n")
        sys.exit(1)
    return val


def env_or(name, fallback):
    return os.environ.get(name, fallback)


def main():
    num_nodes = int(require_env("PLATFORM_NUM_NODES"))
    ranks_per_node = int(require_env("PLATFORM_RANKS_PER_NODE"))
    net_bw = require_env("PLATFORM_NET_BW")
    net_lat = require_env("PLATFORM_NET_LAT")
    intra_bw = env_or("PLATFORM_INTRA_BW", "200GBps")
    intra_lat = env_or("PLATFORM_INTRA_LAT", "0.1us")
    hostfile_path = require_env("PLATFORM_HOSTFILE")
    xml_out = env_or("PLATFORM_XML_OUT", "platform_shared_nic.xml")
    # NIC link sharing policy. SHARED (SimGrid's default, and what every run
    # before 2026-10-02 used): send and receive traffic of a node share one
    # net_bw budget. SPLITDUPLEX: each direction has its own net_bw.
    # Selectable so both can be run on the same configs.
    nic_sharing = env_or("PLATFORM_NIC_SHARING", "SHARED").upper()
    if nic_sharing not in ("SHARED", "SPLITDUPLEX"):
        sys.stderr.write(f"Error: PLATFORM_NIC_SHARING must be SHARED or SPLITDUPLEX, got '{nic_sharing}'.\n")
        sys.exit(1)

    total_hosts = num_nodes * ranks_per_node

    print("Platform configuration (shared-NIC model, XML backend):")
    print(f"  num_nodes: {num_nodes}")
    print(f"  ranks_per_node: {ranks_per_node}")
    print(f"  net_bw (shared, per node): {net_bw}")
    print(f"  net_lat: {net_lat}")
    print(f"  nic_sharing: {nic_sharing}")
    print(f"  intra_bw (per rank, within node): {intra_bw}")
    print(f"  intra_lat: {intra_lat}")
    print(f"  hostfile_path: {hostfile_path}")
    print(f"  xml_out: {xml_out}")

    # SimGrid's platform DTD requires all AS/host/router (topology) elements
    # in a zone before any link, and all links before any route -- an
    # element ordering it enforces strictly (confirmed live: "<host> is not
    # allowed here" when interleaved by node, as the C++ version's
    # per-node loop structure naturally does). Emit in three DTD-compliant
    # passes -- routers+hosts, then links, then routes -- instead of
    # interleaving per node.
    routers, hosts, links, routes = [], [], [], []

    routers.append('    <router id="global_switch"/>')

    for i in range(num_nodes):
        node_switch = f"node_switch_{i}"
        node_link = f"node_link_{i}"
        routers.append(f'    <router id="{node_switch}"/>')
        if nic_sharing == "SHARED":
            links.append(f'    <link id="{node_link}" bandwidth="{net_bw}" latency="{net_lat}"/>')
            routes.append(f'    <route src="{node_switch}" dst="global_switch">')
            routes.append(f'      <link_ctn id="{node_link}"/>')
            routes.append("    </route>")
        else:
            # Split link: outbound traffic uses the UP half, inbound the DOWN
            # half, so the two directions are declared as separate,
            # non-symmetrical routes.
            links.append(f'    <link id="{node_link}" bandwidth="{net_bw}" latency="{net_lat}" sharing_policy="SPLITDUPLEX"/>')
            routes.append(f'    <route src="{node_switch}" dst="global_switch" symmetrical="NO">')
            routes.append(f'      <link_ctn id="{node_link}" direction="UP"/>')
            routes.append("    </route>")
            routes.append(f'    <route src="global_switch" dst="{node_switch}" symmetrical="NO">')
            routes.append(f'      <link_ctn id="{node_link}" direction="DOWN"/>')
            routes.append("    </route>")

        for j in range(ranks_per_node):
            rank = i * ranks_per_node + j
            host_name = f"host-{rank}"
            intra_link = f"intra_link_{rank}"
            hosts.append(f'    <host id="{host_name}" speed="1f"/>')
            links.append(f'    <link id="{intra_link}" bandwidth="{intra_bw}" latency="{intra_lat}"/>')
            routes.append(f'    <route src="{host_name}" dst="{node_switch}">')
            routes.append(f'      <link_ctn id="{intra_link}"/>')
            routes.append("    </route>")

    lines = []
    lines.append("<?xml version='1.0'?>")
    lines.append('<!DOCTYPE platform SYSTEM "https://simgrid.org/simgrid.dtd">')
    lines.append('<platform version="4.1">')
    lines.append('  <zone id="world" routing="Floyd">')
    lines.extend(routers)
    lines.extend(hosts)
    lines.extend(links)
    lines.extend(routes)
    lines.append("  </zone>")
    lines.append("</platform>")

    with open(xml_out, "w") as f:
        f.write("\n".join(lines) + "\n")

    with open(hostfile_path, "w") as f:
        for k in range(total_hosts):
            f.write(f"host-{k}\n")

    print(f"[Generator] Wrote {xml_out} and {hostfile_path}")
    print(f"[Generator] Generated {total_hosts} hosts ({num_nodes} nodes x {ranks_per_node} ranks).")


if __name__ == "__main__":
    main()
