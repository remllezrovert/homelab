# ---------------------------------------------------------------------------
# EVPN VNet subnet services and OpenWrt container
#
# This file owns:
# - Proxmox SDN subnet gateway/SNAT declarations
# - Applying those declarations
# - The OpenWrt CT lifecycle
# - OpenWrt CT NIC attachment to every var.subnets EVPN VNet
#
# Proxmox SDN owns:
# - EVPN/VNet connectivity
# - Gateway addresses declared below
# - SNAT through EVPN exit nodes
#
# OpenWrt owns:
# - DHCP and DNS service
# - In-guest UCI configuration, managed in config-network
#
# The canonical VNet/subnet values come from var.subnets, supplied by this
# root module's terraform.tfvars.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Proxmox SDN subnet declarations
#
# One PVE subnet object per var.subnets map item:
#
#   proxmox_sdn_subnet.subnet["k8sctl"]
#   proxmox_sdn_subnet.subnet["k8swrk"]
# ---------------------------------------------------------------------------

resource "proxmox_sdn_subnet" "subnet" {
  for_each = var.subnets

  vnet    = proxmox_sdn_vnet.subnet[each.key].id
  cidr    = each.value.cidr
  gateway = each.value.gateway
  snat    = each.value.snat

  depends_on = [
    proxmox_sdn_vnet.subnet,
  ]
}
resource "proxmox_sdn_applier" "subnet_applier" {
  lifecycle {
    replace_triggered_by = [
      proxmox_sdn_subnet.subnet,
    ]
  }

  depends_on = [
    proxmox_sdn_subnet.subnet,
  ]
}

# ---------------------------------------------------------------------------
# OpenWrt CT infrastructure
#
# eth0 is the fixed management NIC:
#   vmbr0 + VLAN 12 -> 192.168.2.2/24
#
# Every extra NIC is generated from var.subnets:
#   k8sctl -> eth1 -> k8sctl VNet
#   k8swrk -> eth2 -> k8swrk VNet
#
# The VNet itself is read from the corresponding for_each-created SDN VNet.
# ---------------------------------------------------------------------------

resource "proxmox_virtual_environment_container" "openwrt_01" {
  vm_id     = 101
  node_name = "mgmt1"

  description = "OpenWrt DHCP/DNS server for Terraform-managed EVPN VNets"
  tags        = ["terraform", "openwrt", "dns", "dhcp", "net-utils"]

  started       = true
  start_on_boot = true
  unprivileged  = false

  clone {
    vm_id        = 906
    node_name    = "mgmt1"
    datastore_id = "proxpool"
    full         = true
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 500
    swap      = 0
  }

  disk {
    datastore_id = "proxpool"
    size         = 2
  }

  # Fixed management NIC.
  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    vlan_id = 12
  }

  # One generated NIC per canonical subnet definition.
  #
  # For current terraform.tfvars:
  #   eth1 -> k8sctl
  #   eth2 -> k8swrk
  dynamic "network_interface" {
    for_each = var.subnets

    iterator = subnet

    content {
      name   = subnet.value.openwrt_device
      bridge = proxmox_sdn_vnet.subnet[subnet.key].id
    }
  }

  initialization {
    hostname = "openwrt-01"

    # Proxmox LXC initial management connectivity.
    # In-guest UCI management is configured by config-network.
    ip_config {
      ipv4 {
        address = "${var.openwrt_ip}/24"
        gateway = "192.168.2.1"
      }
    }
  }

  depends_on = [
    proxmox_sdn_applier.vnet_applier,
    proxmox_sdn_applier.subnet_applier,
  ]
}

