# ---------------------------------------------------------------------------
# OpenWrt provider and in-guest UCI network configuration
#
# This Terraform root manages OpenWrt UCI network configuration inside
# Proxmox CT 101.
#
# Prerequisites:
# - infra-network has created and started CT 101.
# - CT 101 is reachable at var.openwrt_ip over its VLAN 12 management network.
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
#
# CT 101 eth0 is already a member port of the template-created br-lan bridge.
#
# OpenWrt topology:
#   lan -> br-lan -> eth0 -> VLAN 12 -> 192.168.2.101/24
#
# Do not create a second "mgmt" interface directly on eth0. Doing so conflicts
# with eth0's existing br-lan bridge membership and duplicates the management
# IP address/subnet.
# ---------------------------------------------------------------------------

resource "openwrt_network_interface" "lan" {
  id     = "lan"
  device = "br-lan"
  proto  = "static"

  ipaddr  = var.openwrt_ip
  netmask = "255.255.255.0"
  gateway = "192.168.2.1"

  dns = [
    "192.168.2.1",
  ]
}

# ---------------------------------------------------------------------------
# Kubernetes control-plane network
#
# CT 101 eth1:
#   Proxmox VNet:    k8sctl
#   OpenWrt device:  eth1
#   OpenWrt address: 10.8.0.101/24
#
# Proxmox EVPN gateway: 10.8.0.1
# ---------------------------------------------------------------------------

resource "openwrt_network_interface" "k8sctl" {
  id     = "k8sctl"
  device = "eth1"
  proto  = "static"

  ipaddr  = "10.8.0.101"
  netmask = "255.255.255.0"
}

# ---------------------------------------------------------------------------
# Kubernetes worker network
#
# CT 101 eth2:
#   Proxmox VNet:    k8swrk
#   OpenWrt device:  eth2
#   OpenWrt address: 10.8.1.101/24
#
# Proxmox EVPN gateway: 10.8.1.1
# ---------------------------------------------------------------------------

resource "openwrt_network_interface" "k8swrk" {
  id     = "k8swrk"
  device = "eth2"
  proto  = "static"

  ipaddr  = "10.8.1.101"
  netmask = "255.255.255.0"
}
