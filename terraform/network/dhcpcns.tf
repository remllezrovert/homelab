# ---------------------------------------------------------------------------
# OpenWrt DHCP and DNS
#
# OpenWrt CT 101 provides DHCP and DNS on:
#
#   k8sctl / eth1 / 10.8.0.0/24
#     OpenWrt DHCP/DNS: 10.8.0.101
#     Proxmox EVPN gateway: 10.8.0.1
#     Dynamic pool: 10.8.0.50 through 10.8.0.100
#
#   k8swrk / eth2 / 10.8.1.0/24
#     OpenWrt DHCP/DNS: 10.8.1.101
#     Proxmox EVPN gateway: 10.8.1.1
#     Dynamic pool: 10.8.1.50 through 10.8.1.100
#
# Do not create DHCP scopes on the management VLAN unless OpenWrt is
# confirmed to be the only DHCP server on 192.168.2.0/24.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Global dnsmasq instance
#
# "cfg01411c" is the default anonymous UCI dnsmasq section ID on many
# stock OpenWrt images. Verify it on CT 101 before applying:
#
#   uci show dhcp | grep '=dnsmasq'
#
# If it reports a different ID, replace cfg01411c below with that value.
# ---------------------------------------------------------------------------

resource "openwrt_dhcp_dnsmasq" "main" {
  id = "cfg01411c"

  authoritative     = true
  domain            = "home.arpa"
  domainneeded      = true
  expandhosts       = true
  local             = "/home.arpa/"
  localise_queries  = true
  localservice      = true
  readethers        = true
  rebind_protection = true

  leasefile  = "/tmp/dhcp.leases"
  resolvfile = "/tmp/resolv.conf.d/resolv.conf.auto"

  depends_on = [
    openwrt_network_interface.mgmt,
    openwrt_network_interface.k8sctl,
    openwrt_network_interface.k8swrk,
  ]
}

# ---------------------------------------------------------------------------
# DHCP scope: k8sctl
#
# OpenWrt interface: eth1 / k8sctl / 10.8.0.101
# Dynamic leases:     10.8.0.50 through 10.8.0.100
#
# dnsmasq will serve DHCP on the k8sctl interface. Without an explicit
# dhcp_option field in this provider version, DHCP clients use the
# interface address 10.8.0.101 as their router and DNS server.
# ---------------------------------------------------------------------------

resource "openwrt_dhcp_dhcp" "k8sctl" {
  id = "k8sctl"

  interface = "k8sctl"
  start     = 50
  limit     = 51
  leasetime = "12h"

  depends_on = [
    openwrt_dhcp_dnsmasq.main,
    openwrt_network_interface.k8sctl,
  ]
}

# ---------------------------------------------------------------------------
# DHCP scope: k8swrk
#
# OpenWrt interface: eth2 / k8swrk / 10.8.1.101
# Dynamic leases:     10.8.1.50 through 10.8.1.100
#
# dnsmasq will serve DHCP on the k8swrk interface. Without an explicit
# dhcp_option field in this provider version, DHCP clients use the
# interface address 10.8.1.101 as their router and DNS server.
# ---------------------------------------------------------------------------

resource "openwrt_dhcp_dhcp" "k8swrk" {
  id = "k8swrk"

  interface = "k8swrk"
  start     = 50
  limit     = 51
  leasetime = "12h"

  depends_on = [
    openwrt_dhcp_dnsmasq.main,
    openwrt_network_interface.k8swrk,
  ]
}
