# ---------------------------------------------------------------------------
# OpenWrt DHCP and DNS
#
# The OpenWrt router must already exist and be reachable at var.openwrt_ip.
#
# This root manages:
# - The existing dnsmasq UCI section.
# - One DHCPv4 scope per entry in var.subnets.
#
# Each subnet entry must identify an existing OpenWrt UCI network interface
# whose name matches the subnet map key.
#
# Example:
#
#   subnets.k8sctl
#     -> UCI interface k8sctl
#     -> OpenWrt DHCP section k8sctl
#     -> pool begins at subnet host offset 3
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
  domain            = var.dns_domain
  domainneeded      = true
  expandhosts       = true
  local             = "/${var.dns_domain}/"
  localise_queries  = true
  localservice      = true
  readethers        = true
  rebind_protection = true

  leasefile  = "/tmp/dhcp.leases"
  resolvfile = "/tmp/resolv.conf.d/resolv.conf.auto"
}


# ---------------------------------------------------------------------------
# DHCPv4 scopes for EVPN-backed OpenWrt interfaces

locals {
  dhcp_pool_start = 3

  dhcp_subnets = {
    for name, subnet in var.subnets : name => merge(subnet, {
      prefix_length = tonumber(split("/", subnet.cidr)[1])

      dhcp_pool_limit = pow(2, 32 - tonumber(split("/", subnet.cidr)[1])) - local.dhcp_pool_start - 1
    })
  }
}

resource "openwrt_dhcp_dhcp" "subnet" {
  for_each = local.dhcp_subnets

  id        = each.key
  interface = openwrt_network_interface.subnet[each.key].id

  dhcpv4    = "server"
  start     = local.dhcp_pool_start
  limit     = each.value.dhcp_pool_limit
  leasetime = "12h"

  depends_on = [
    openwrt_dhcp_dnsmasq.main,
  ]
}
