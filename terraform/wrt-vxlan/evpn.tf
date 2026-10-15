# ---------------------------------------------------------------------------
# Initial SDN configuration apply
# ---------------------------------------------------------------------------

resource "proxmox_sdn_applier" "initial_applier" {}

# ---------------------------------------------------------------------------
# Plain VXLAN zone
#
# No EVPN controller, OpenFabric, or OSPF.
# Existing variable names are retained for terraform.tfvars compatibility.
# ---------------------------------------------------------------------------

resource "proxmox_sdn_zone_vxlan" "main" {
  id    = var.evpn.zone_id
  nodes = sort(keys(var.proxmox_hosts))

  peers = toset([
    for host in values(var.proxmox_hosts) :
    host.vxlan_peer_ipv4
  ])

  mtu  = var.evpn.mtu
  ipam = var.evpn.ipam

  depends_on = [
    proxmox_sdn_applier.initial_applier,
  ]
}

resource "proxmox_sdn_applier" "zone_applier" {
  lifecycle {
    replace_triggered_by = [
      proxmox_sdn_zone_vxlan.main,
    ]
  }

  depends_on = [
    proxmox_sdn_zone_vxlan.main,
  ]
}

# ---------------------------------------------------------------------------
# VXLAN VNets
#
# One VNet per subnets map item.
# Existing VNet resource addresses, IDs, and VNIs are retained.
# Subnet declarations remain in subnets.tf.
# ---------------------------------------------------------------------------

resource "proxmox_sdn_vnet" "subnet" {
  for_each = var.subnets

  id   = each.key
  zone = proxmox_sdn_zone_vxlan.main.id
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
# Retain the existing VNet migrations.
# Fabric resources are removed, so their moved blocks are removed too.
# ---------------------------------------------------------------------------

moved {
  from = proxmox_sdn_vnet.k8s_control
  to   = proxmox_sdn_vnet.subnet["k8sctl"]
}

moved {
  from = proxmox_sdn_vnet.k8s_workers
  to   = proxmox_sdn_vnet.subnet["k8swrk"]
}
