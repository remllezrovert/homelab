# ---------------------------------------------------------------------------
# OpenWrt provider authentication
#
# Non-secret values are supplied from ../terraform.tfvars.
# The password is supplied from .env as TF_VAR_openwrt_password.
# ---------------------------------------------------------------------------

variable "dns_domain" {
  description = "DNS suffix advertised by OpenWrt DHCP and served locally by dnsmasq."
  type        = string
}

# ---------------------------------------------------------------------------
# OpenWrt management network
#
# Used by the existing `lan` UCI interface:
#
#   lan -> br-lan -> eth0 -> VLAN 12
# ---------------------------------------------------------------------------

variable "openwrt_management_network" {
  description = "OpenWrt management interface network, default gateway, and resolver configuration."

  type = object({
    cidr    = string
    gateway = string
    dns     = list(string)
  })

  validation {
    condition     = can(cidrnetmask(var.openwrt_management_network.cidr))
    error_message = "openwrt_management_network.cidr must be a valid IPv4 CIDR, for example 192.168.2.0/24."
  }

  validation {
    condition     = can(cidrhost("${var.openwrt_management_network.gateway}/32", 0))
    error_message = "openwrt_management_network.gateway must be a valid IPv4 address."
  }

  validation {
    condition = alltrue([
      for server in var.openwrt_management_network.dns :
      can(cidrhost("${server}/32", 0))
    ])
    error_message = "Every openwrt_management_network.dns entry must be a valid IPv4 address."
  }
}

# ---------------------------------------------------------------------------
# EVPN-backed OpenWrt interfaces
#
# Each map entry creates:
#
#   openwrt_network_interface.subnet["<subnet-name>"]
#
# `gateway` is the OpenWrt interface address in the existing tfvars design.
# It is not the PVE EVPN anycast gateway address.
# ---------------------------------------------------------------------------

variable "subnets" {
  description = "EVPN subnet definitions and their corresponding OpenWrt device assignments."

  type = map(object({
    vni            = number
    cidr           = string
    gateway        = string
    snat           = bool
    openwrt_device = string
  }))

  validation {
    condition = alltrue([
      for name, subnet in var.subnets :
      can(cidrnetmask(subnet.cidr))
    ])
    error_message = "Every subnets.<name>.cidr value must be a valid IPv4 CIDR."
  }

  validation {
    condition = alltrue([
      for name, subnet in var.subnets :
      can(cidrhost("${subnet.gateway}/32", 0))
    ])
    error_message = "Every subnets.<name>.gateway value must be a valid IPv4 address."
  }

  validation {
    condition = alltrue([
      for name, subnet in var.subnets :
      subnet.vni >= 1 && subnet.vni <= 16777215
    ])
    error_message = "Every subnets.<name>.vni must be within the valid VXLAN VNI range of 1 through 16777215."
  }

  validation {
    condition = alltrue([
      for name, subnet in var.subnets :
      length(trimspace(subnet.openwrt_device)) > 0
    ])
    error_message = "Every subnets.<name>.openwrt_device must be a non-empty OpenWrt device name."
  }
}
