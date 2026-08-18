// platform_shared_nic.cpp — SimGrid S4U platform generator for the chuc
// validation campaign (Option C, see project conversation log).
//
// This is a NEW file, not a modification of simgrid-config/platform_s4u.cpp,
// precisely so the original, already-used-for-published-numbers platform
// generator stays untouched.
//
// Difference from simgrid-config/platform_s4u.cpp: that file gives every
// simulated host its OWN dedicated link to the switch (1 process = 1 whole
// link), matching Spadotto's original poti calibration (1 GPU per node).
// This file instead models PLATFORM_RANKS_PER_NODE processes sharing ONE
// external link per physical node — the chuc reality (4 GPUs/node behind
// one shaped NIC) that the original platform never represented. All
// Cornebize-calibrated smpi/* protocol parameters (os/or/ois, bw-factor,
// lat-factor, thresholds — see nix/scripts.nix's runSimgridPlatformCuda)
// are reused verbatim by the caller; nothing here recalibrates them, only
// the network TOPOLOGY changes.
//
// Topology per node i:
//   host-{i*RANKS_PER_NODE+j}  --intra_link(fast)--  node_switch_i
//   node_switch_i              --node_link_i(shaped)-- global_switch
//
// node_link_i is the ONE link shared by all RANKS_PER_NODE hosts on node i:
// SimGrid's flow-level solver max-min-fair-shares it across every
// simultaneous flow that uses it, so N ranks on the same node exchanging
// data with remote ranks at the same time genuinely contend for that node's
// bandwidth, instead of each pretending to own the full shaped rate.
//
// intra_link is deliberately generous (default 200GBps / ~0us), standing in
// for the NVLink/shared-memory path real co-located ranks use on chuc
// (Section 5.1 of papers/2026_chuc_gpu_validation/main.tex: intra-node MPI
// traffic never crosses the shaped interface) — so same-node communication
// is not artificially bottlenecked by this model, matching the real
// single-node measurement (ME statistically flat across 1/10/25 Gbit/s at
// one node, see Table 3 / RESULTADOS_PACOTE.md).
//
// With PLATFORM_NUM_NODES=1, this collapses to the same effective topology
// as the original platform_s4u.cpp (all traffic local, one shared node link
// that no inter-node flow ever needs) — a useful sanity check before trusting
// the 2/3/4-node runs.
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <simgrid/s4u.hpp>
#include <string>
#include <vector>

struct PlatformConfig {
  int num_nodes;
  int ranks_per_node;
  std::string net_bw;   // shared external NIC, per node
  std::string net_lat;
  std::string intra_bw;  // intra-node (NVLink/shared-memory stand-in)
  std::string intra_lat;
  std::string hostfile_path;

  static std::string require_env_var(const char *name) {
    const char *val = std::getenv(name);
    if (!val) {
      std::cerr << "Error: Environment variable '" << name
                << "' is required but not set." << std::endl;
      std::exit(1);
    }
    return std::string(val);
  }

  static std::string env_var_or(const char *name, const std::string &fallback) {
    const char *val = std::getenv(name);
    return val ? std::string(val) : fallback;
  }

  static PlatformConfig load() {
    PlatformConfig cfg;
    cfg.num_nodes = std::stoi(require_env_var("PLATFORM_NUM_NODES"));
    cfg.ranks_per_node = std::stoi(require_env_var("PLATFORM_RANKS_PER_NODE"));
    cfg.net_bw = require_env_var("PLATFORM_NET_BW");
    cfg.net_lat = require_env_var("PLATFORM_NET_LAT");
    cfg.intra_bw = env_var_or("PLATFORM_INTRA_BW", "200GBps");
    cfg.intra_lat = env_var_or("PLATFORM_INTRA_LAT", "0.1us");
    cfg.hostfile_path = require_env_var("PLATFORM_HOSTFILE");
    std::cout << "Platform configuration (shared-NIC model):" << std::endl;
    std::cout << "  num_nodes: " << cfg.num_nodes << std::endl;
    std::cout << "  ranks_per_node: " << cfg.ranks_per_node << std::endl;
    std::cout << "  net_bw (shared, per node): " << cfg.net_bw << std::endl;
    std::cout << "  net_lat: " << cfg.net_lat << std::endl;
    std::cout << "  intra_bw (per rank, within node): " << cfg.intra_bw << std::endl;
    std::cout << "  intra_lat: " << cfg.intra_lat << std::endl;
    std::cout << "  hostfile_path: " << cfg.hostfile_path << std::endl;
    return cfg;
  }

  int total_hosts() const { return num_nodes * ranks_per_node; }
};

extern "C" void load_platform(simgrid::s4u::Engine &e) {
  PlatformConfig cfg = PlatformConfig::load();
  std::cout << "[S4U Plugin] Loading shared-NIC platform: " << cfg.num_nodes
            << " node(s) x " << cfg.ranks_per_node << " rank(s)." << std::endl;

  auto *root = e.get_netzone_root();
  simgrid::s4u::NetZone *zone = nullptr;
  if (root) {
    zone = root->add_netzone_floyd("world");
  } else {
    zone = e.get_netzone_root()->add_netzone_floyd("world");
  }

  auto *global_switch = zone->add_router("global_switch");

  for (int i = 0; i < cfg.num_nodes; ++i) {
    std::string node_switch_name = "node_switch_" + std::to_string(i);
    std::string node_link_name = "node_link_" + std::to_string(i);

    auto *node_switch = zone->add_router(node_switch_name);

    // The ONE link shared by every rank on this node -- this is the object
    // that makes contention real: every host below routes its inter-node
    // traffic through this same Link, so SimGrid's max-min fair-share
    // solver divides its capacity across however many ranks are sending
    // concurrently, instead of granting each rank the full nominal rate.
    auto *node_link = zone->add_link(node_link_name, cfg.net_bw)->set_latency(cfg.net_lat);
    std::vector<const simgrid::s4u::Link *> uplink_route = {node_link};
    zone->add_route(node_switch, global_switch, uplink_route);

    for (int j = 0; j < cfg.ranks_per_node; ++j) {
      int rank = i * cfg.ranks_per_node + j;
      std::string host_name = "host-" + std::to_string(rank);
      std::string intra_link_name = "intra_link_" + std::to_string(rank);

      auto *host = zone->add_host(host_name, "1f");
      auto *intra_link = zone->add_link(intra_link_name, cfg.intra_bw)->set_latency(cfg.intra_lat);
      std::vector<const simgrid::s4u::Link *> intra_route = {intra_link};
      zone->add_route(host->get_netpoint(), node_switch, intra_route);
    }
  }

  zone->seal();
}

int main(int argc, char *argv[]) {
  PlatformConfig cfg = PlatformConfig::load();

  std::cout << "[Generator] Writing hostfile to: " << cfg.hostfile_path << std::endl;
  std::ofstream hf(cfg.hostfile_path);
  if (!hf.is_open()) {
    std::cerr << "Error: Could not open " << cfg.hostfile_path << " for writing." << std::endl;
    return 1;
  }

  // Rank k -> host-k, in order, so rank blocks [0..ranks_per_node) land on
  // node 0, [ranks_per_node..2*ranks_per_node) on node 1, etc. -- the same
  // contiguous block assignment MPI_MAP_BY=slot uses in the real campaign
  // (g5k/conf/defaults.conf), so "which ranks are local to each other" in
  // this simulation matches the real hostfile's grouping.
  for (int k = 0; k < cfg.total_hosts(); ++k) {
    hf << "host-" << k << std::endl;
  }
  hf.close();

  std::cout << "[Generator] Generated " << cfg.total_hosts() << " hosts ("
            << cfg.num_nodes << " nodes x " << cfg.ranks_per_node << " ranks)." << std::endl;
  return 0;
}
