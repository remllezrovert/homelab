# ---------------------------------------------------------------------------
# EVPN controller
#
# This controller uses the OpenFabric underlay declared in routing.tf.
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
# vrf_vxlan is the EVPN L3 VRF VNI.
# VNet tags are EVPN L2 VXLAN VNIs.
#
# dhcp = "dnsmasq" enables Proxmox SDN-managed DHCP for subnets created in
# this zone. Individual DHCP lease pools are configured in subnets.tf.
#
# A single exit node is deliberate during initial deployment. It gives SNAT
# traffic a deterministic egress path:
#
#   guest → EVPN gateway → mgmt1 → mgmt1 LAN/uplink → Internet
#
# Add more exit nodes only after DHCP, DNS, routing, SNAT, and return traffic
# are confirmed to work with one exit node.
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
# Gateways, DHCP ranges, DHCP DNS settings, and SNAT are defined in
# subnets.tf, not here.
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
# Apply the VNet definitions.
#
# subnets.tf contains a separate subnet_applier that runs after subnet, DHCP,
# gateway, DNS, and SNAT settings have been created.
# ---------------------------------------------------------------------------

resource "proxmox_sdn_applier" "vnet_applier" {
  depends_on = [
    proxmox_sdn_vnet.k8s_control,
    proxmox_sdn_vnet.k8s_workers,
  ]
}
