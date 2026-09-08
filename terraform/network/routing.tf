# ---------------------------------------------------------------------------
# OpenFabric routing underlay
#
# The fabric provides routed transport between Proxmox nodes.
# It is not a guest VNet and is not the physical LAN bridge.
# ---------------------------------------------------------------------------

resource "proxmox_sdn_applier" "initial_applier" {
}

resource "proxmox_sdn_fabric_openfabric" "main" {
  id        = "main"
  ip_prefix = "10.0.0.0/16"

  depends_on = [
    proxmox_sdn_applier.initial_applier,
  ]
}

# ---------------------------------------------------------------------------
# OpenFabric node membership
#
# Fabric IPs are internal OpenFabric router addresses.
# interface_names must be the intended underlay interface on each node.
# ---------------------------------------------------------------------------

resource "proxmox_sdn_fabric_node_openfabric" "mgmt1" {
  fabric_id       = proxmox_sdn_fabric_openfabric.main.id
  node_id         = "mgmt1"
  ip              = "10.0.0.11"
  interface_names = ["eno1"]
}

resource "proxmox_sdn_fabric_node_openfabric" "mgmt2" {
  fabric_id       = proxmox_sdn_fabric_openfabric.main.id
  node_id         = "mgmt2"
  ip              = "10.0.0.12"
  interface_names = ["enp0s31f6"]
}

resource "proxmox_sdn_fabric_node_openfabric" "mgmt3" {
  fabric_id       = proxmox_sdn_fabric_openfabric.main.id
  node_id         = "mgmt3"
  ip              = "10.0.0.13"
  interface_names = ["nic0"]
}
