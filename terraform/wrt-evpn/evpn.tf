# ---------------------------------------------------------------------------
# Initial SDN configuration apply
# ---------------------------------------------------------------------------

resource "proxmox_sdn_applier" "initial_applier" {}

# ---------------------------------------------------------------------------
# OpenFabric routing underlay
# ---------------------------------------------------------------------------

resource "proxmox_sdn_fabric_openfabric" "main" {
  id        = var.openfabric.id
  ip_prefix = var.openfabric.ip_prefix

  depends_on = [
    proxmox_sdn_applier.initial_applier,
  ]
}



resource "proxmox_sdn_fabric_node_openfabric" "host" {
  for_each = var.proxmox_hosts

  fabric_id       = proxmox_sdn_fabric_openfabric.main.id
  node_id         = each.key
  ip              = each.value.openfabric_ipv4
  interface_names = each.value.openfabric_interfaces
}

# ---------------------------------------------------------------------------
# EVPN controller
# ---------------------------------------------------------------------------

resource "proxmox_sdn_controller_evpn" "main" {
  id     = var.evpn.controller_id
  asn    = var.evpn.asn
  fabric = proxmox_sdn_fabric_openfabric.main.id

  depends_on = [
    proxmox_sdn_fabric_node_openfabric.host,
  ]
}

resource "proxmox_sdn_applier" "controller_applier" {
  depends_on = [
    proxmox_sdn_controller_evpn.main,
  ]
}

# ---------------------------------------------------------------------------
# EVPN zone
# ---------------------------------------------------------------------------

resource "proxmox_sdn_zone_evpn" "main" {
  id         = var.evpn.zone_id
  nodes      = sort(keys(var.proxmox_hosts))
  controller = proxmox_sdn_controller_evpn.main.id

  vrf_vxlan = var.evpn.vrf_vxlan
  mtu       = var.evpn.mtu
  ipam      = var.evpn.ipam

  advertise_subnets          = var.evpn.advertise_subnets
  disable_arp_nd_suppression = var.evpn.disable_arp_nd_suppression

  exit_nodes               = var.evpn.exit_nodes
  exit_nodes_local_routing = var.evpn.exit_nodes_local_routing
  primary_exit_node        = var.evpn.primary_exit_node
  rt_import                = var.evpn.rt_import

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
# EVPN VNets
#
# One VNet per subnets map item.
# VNet/subnet gateway/SNAT configuration remains in subnets.tf.
# ---------------------------------------------------------------------------

resource "proxmox_sdn_vnet" "subnet" {
  for_each = var.subnets

  id   = each.key
  zone = proxmox_sdn_zone_evpn.main.id
  tag  = each.value.vni

  depends_on = [
    proxmox_sdn_applier.zone_applier,
  ]
}

resource "proxmox_sdn_applier" "vnet_applier" {
  lifecycle {
    replace_triggered_by = [
      proxmox_sdn_vnet.subnet,
    ]
  }

  depends_on = [
    proxmox_sdn_vnet.subnet,
  ]
}

# ---------------------------------------------------------------------------
# State-address migrations
#
# These preserve all existing resources when moving from static declarations
# to for_each map-key addresses.
#
# Keep these blocks until the refactor has been applied successfully.
# ---------------------------------------------------------------------------

moved {
  from = proxmox_sdn_fabric_node_openfabric.mgmt1
  to   = proxmox_sdn_fabric_node_openfabric.host["mgmt1"]
}

moved {
  from = proxmox_sdn_fabric_node_openfabric.mgmt2
  to   = proxmox_sdn_fabric_node_openfabric.host["mgmt2"]
}

moved {
  from = proxmox_sdn_fabric_node_openfabric.mgmt3
  to   = proxmox_sdn_fabric_node_openfabric.host["mgmt3"]
}

moved {
  from = proxmox_sdn_vnet.k8s_control
  to   = proxmox_sdn_vnet.subnet["k8sctl"]
}

moved {
  from = proxmox_sdn_vnet.k8s_workers
  to   = proxmox_sdn_vnet.subnet["k8swrk"]
}
