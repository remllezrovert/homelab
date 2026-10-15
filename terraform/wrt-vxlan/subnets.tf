# ---------------------------------------------------------------------------
# VXLAN VNet subnet inventory and OpenWrt container
#
# This file owns:
# - Proxmox SDN subnet CIDR declarations
# - Applying those declarations
# - The OpenWrt CT lifecycle
# - OpenWrt CT NIC attachment to every var.subnets VNet
#
# Proxmox SDN owns:
# - VXLAN/VNet Layer-2 connectivity
# - Subnet inventory only
#
# OpenWrt owns:
# - Its existing interface addresses from var.subnets[*].gateway
# - Routing and firewall policy
# - Upstream NAT
# - DHCP and DNS service
# - In-guest UCI configuration, managed in config-network
#
# No gateway address is assigned to Proxmox.
# Proxmox SNAT is explicitly disabled.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Proxmox SDN subnet inventory
#
# var.subnets[*].gateway remains the OpenWrt address.
# It is deliberately NOT assigned as a Proxmox subnet gateway.
#
# var.subnets[*].snat is retained as a legacy input but is not used here.
# ---------------------------------------------------------------------------

resource "proxmox_sdn_subnet" "subnet" {
  for_each = var.subnets

  vnet = proxmox_sdn_vnet.subnet[each.key].id
  cidr = each.value.cidr

  snat = false

  depends_on = [
    proxmox_sdn_applier.vnet_applier,
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
# eth0 retains the existing management/upstream connection:
#   vmbr0 + VLAN 12 -> var.openwrt_ip/24
#
# Every extra NIC is generated from var.subnets.
# Device names and VNet attachments remain unchanged.
#
# In-guest interface addresses, routing, firewall, DHCP, and DNS are managed
# separately by config-network.
# ---------------------------------------------------------------------------

resource "proxmox_virtual_environment_container" "openwrt_01" {
  vm_id     = 101
  node_name = "mgmt1"

  description = "OpenWrt router and DHCP/DNS server for Terraform-managed VXLAN VNets"
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

  # Preserve the existing management/upstream NIC.
  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    vlan_id = 12
  }

  # One generated NIC per canonical subnet definition.
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

    # Preserve existing Proxmox LXC management initialization.
    # In-guest UCI configuration is managed by config-network.
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
