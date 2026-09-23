# ---------------------------------------------------------------------------
# OpenWrt provider and in-guest UCI network configuration
#
# This Terraform root manages OpenWrt UCI network configuration inside
# Proxmox CT 2.
#
# Prerequisites:
# - infra-network has created and started CT 2.
# - CT 2 is reachable at var.openwrt_ip over its VLAN 12 management network.
# - LuCI RPC is available on TCP port 80.
#
# Proxmox SDN owns:
# - EVPN VNet connectivity
# - EVPN anycast gateway addresses
# - SNAT through EVPN exit nodes
#
# OpenWrt owns:
# - DHCP service
# - DNS service
# - In-guest UCI interface configuration
# ---------------------------------------------------------------------------

provider "openwrt" {
  hostname = var.openwrt_ip
  username = var.openwrt_username
  password = var.openwrt_password
  scheme   = "http"
  port     = 80
}

# ---------------------------------------------------------------------------
# Management network
# CT 2 eth0 is already a member port of the template-created br-lan bridge.
# OpenWrt topology:
#   lan -> br-lan -> eth0 -> VLAN 12 -> 192.168.2.2/24
# ---------------------------------------------------------------------------
resource "openwrt_network_interface" "lan" {
  id     = "lan"
  device = "br-lan"
  proto  = "static"

  ipaddr  = var.openwrt_ip
  netmask = cidrnetmask(var.openwrt_management_network.cidr)
  gateway = var.openwrt_management_network.gateway
  dns     = var.openwrt_management_network.dns
}


# ---------------------------------------------------------------------------
# EVPN-backed OpenWrt interfaces
# ---------------------------------------------------------------------------

resource "openwrt_network_interface" "subnet" {
  for_each = var.subnets

  id     = each.key
  device = each.value.openwrt_device
  proto  = "static"

  ipaddr  = each.value.gateway
  netmask = cidrnetmask(each.value.cidr)
}
