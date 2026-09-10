# ---------------------------------------------------------------------------
# Proxmox OpenFabric and EVPN SDN
#
# This file owns only Proxmox SDN API resources:
# - OpenFabric underlay
# - OpenFabric node membership
# - EVPN controller
# - EVPN zone and exit-node policy
# - EVPN VNets
#
# This file does not:
# - SSH to Proxmox hosts
# - Configure host sysctls
# - Modify /etc/sysctl.conf or /etc/sysctl.d
# - Configure OpenWrt
#
# subnets.tf owns:
# - EVPN subnet CIDRs
# - Anycast gateway addresses
# - SNAT intent
# - DHCP ranges
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Initial SDN configuration apply
# ---------------------------------------------------------------------------

resource "proxmox_sdn_applier" "initial_applier" {
}

# ---------------------------------------------------------------------------
# OpenFabric routing underlay
#
# The fabric provides routed transport between Proxmox nodes.
#
# Use the existing vmbr0 interface. Do not use vmbr0.12: that host interface
# does not exist, and this Terraform configuration does not manage host
# network interfaces.
# ---------------------------------------------------------------------------

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
# interface_names must be an existing underlay interface on each node.
# ---------------------------------------------------------------------------

resource "proxmox_sdn_fabric_node_openfabric" "mgmt1" {
  fabric_id       = proxmox_sdn_fabric_openfabric.main.id
  node_id         = "mgmt1"
  ip              = "10.0.0.11"
  interface_names = ["vmbr0"]
}

resource "proxmox_sdn_fabric_node_openfabric" "mgmt2" {
  fabric_id       = proxmox_sdn_fabric_openfabric.main.id
  node_id         = "mgmt2"
  ip              = "10.0.0.12"
  interface_names = ["vmbr0"]
}

resource "proxmox_sdn_fabric_node_openfabric" "mgmt3" {
  fabric_id       = proxmox_sdn_fabric_openfabric.main.id
  node_id         = "mgmt3"
  ip              = "10.0.0.13"
  interface_names = ["vmbr0"]
}

# ---------------------------------------------------------------------------
# EVPN controller
#
# This controller uses the OpenFabric underlay declared above.
# ---------------------------------------------------------------------------

resource "proxmox_sdn_controller_evpn" "main" {
  id     = "evpn1"
  asn    = 65000
  fabric = proxmox_sdn_fabric_openfabric.main.id

  depends_on = [
    proxmox_sdn_fabric_node_openfabric.mgmt1,
    proxmox_sdn_fabric_node_openfabric.mgmt2,
    proxmox_sdn_fabric_node_openfabric.mgmt3,
  ]
}

resource "proxmox_sdn_applier" "controller_applier" {
  depends_on = [
    proxmox_sdn_controller_evpn.main,
  ]
}

# ---------------------------------------------------------------------------
# EVPN zone
#
# VNet tags are EVPN Layer-2 VXLAN VNIs.
# vrf_vxlan is the EVPN Layer-3 VRF VNI.
#
# Guest egress path:
#
#   guest
#     -> anycast gateway, defined in subnets.tf
#     -> EVPN exit node: mgmt1
#     -> mgmt1 uplink/default route
#     -> Internet
#
# SNAT is requested per subnet in subnets.tf.
# ---------------------------------------------------------------------------

resource "proxmox_sdn_zone_evpn" "main" {
  id         = "evpn"
  nodes      = ["mgmt1", "mgmt2", "mgmt3"]
  controller = proxmox_sdn_controller_evpn.main.id

  vrf_vxlan = 4000
  mtu       = 1450
  ipam      = "pve"

  advertise_subnets          = true
  disable_arp_nd_suppression = false

  exit_nodes = [
    "mgmt1",
  ]

  exit_nodes_local_routing = true
  primary_exit_node        = "mgmt1"
  rt_import                = "65000:65000"

  depends_on = [
    proxmox_sdn_applier.controller_applier,
  ]
}

resource "proxmox_sdn_applier" "zone_applier" {
  depends_on = [
    proxmox_sdn_zone_evpn.main,
  ]
}

# ---------------------------------------------------------------------------
# Kubernetes EVPN VNets
#
# k8sctl:
#   L2 VNI/tag: 10001
#   Subnet:     10.8.0.0/24
#   Gateway:    10.8.0.1
#
# k8swrk:
#   L2 VNI/tag: 10002
#   Subnet:     10.8.1.0/24
#   Gateway:    10.8.1.1
#
# Subnet gateway and SNAT declarations belong in subnets.tf.
# ---------------------------------------------------------------------------

resource "proxmox_sdn_vnet" "k8s_control" {
  id   = "k8sctl"
  zone = proxmox_sdn_zone_evpn.main.id
  tag  = 10001

  depends_on = [
    proxmox_sdn_applier.zone_applier,
  ]
}

resource "proxmox_sdn_vnet" "k8s_workers" {
  id   = "k8swrk"
  zone = proxmox_sdn_zone_evpn.main.id
  tag  = 10002

  depends_on = [
    proxmox_sdn_applier.zone_applier,
  ]
}

# ---------------------------------------------------------------------------
# Apply VNet definitions.
#
# The subnet applier in subnets.tf runs after its subnet resources and
# applies the gateway and SNAT settings.
# ---------------------------------------------------------------------------

resource "proxmox_sdn_applier" "vnet_applier" {
  depends_on = [
    proxmox_sdn_vnet.k8s_control,
    proxmox_sdn_vnet.k8s_workers,
  ]
}
