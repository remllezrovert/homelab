# ---------------------------------------------------------------------------
# OpenWrt DHCP and DNS
#
# Assumptions:
#
#   - The OpenWrt router already exists and is reachable at var.openwrt_ip.
#   - UCI interface sections mgmt, k8sctl, and k8swrk already exist.
#   - eth1 is already attached to the k8sctl network.
#   - eth2 is already attached to the k8swrk network.
#
# This root manages the existing dnsmasq UCI section and the DHCP scope
# sections for k8sctl and k8swrk. It does not own Proxmox resources or
# OpenWrt network-interface sections.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Global dnsmasq instance
#
# "cfg01411c" must match the existing anonymous dnsmasq UCI section ID:
#
#   uci show dhcp | grep '=dnsmasq'
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
}

# ---------------------------------------------------------------------------
# DHCP scope: k8sctl
#
# Existing OpenWrt interface: k8sctl / eth1 / 10.8.0.101
# Dynamic pool:               10.8.0.50 through 10.8.0.100
# ---------------------------------------------------------------------------

resource "openwrt_dhcp_dhcp" "k8sctl" {
  id = "k8sctl"

  interface = "k8sctl"
  start     = 50
  limit     = 51
  leasetime = "12h"

  depends_on = [
    openwrt_dhcp_dnsmasq.main,
  ]
}

# ---------------------------------------------------------------------------
# DHCP scope: k8swrk
#
# Existing OpenWrt interface: k8swrk / eth2 / 10.8.1.101
# Dynamic pool:               10.8.1.50 through 10.8.1.100
# ---------------------------------------------------------------------------

resource "openwrt_dhcp_dhcp" "k8swrk" {
  id = "k8swrk"

  interface = "k8swrk"
  start     = 50
  limit     = 51
  leasetime = "12h"

  depends_on = [
    openwrt_dhcp_dnsmasq.main,
  ]
}
