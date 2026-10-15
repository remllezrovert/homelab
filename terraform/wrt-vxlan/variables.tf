# ---------------------------------------------------------------------------
# Plain VXLAN / OpenWrt inventory inputs
#
# Values are assigned in terraform.tfvars.
# ---------------------------------------------------------------------------

variable "proxmox_hosts" {
  description = "Proxmox nodes keyed by exact Proxmox node name."

  type = map(object({
    vxlan_peer_ipv4 = string
  }))

  validation {
    condition     = length(var.proxmox_hosts) > 0
    error_message = "proxmox_hosts must define at least one Proxmox node."
  }

  validation {
    condition = alltrue([
      for host in values(var.proxmox_hosts) :
      can(cidrhost("${host.vxlan_peer_ipv4}/32", 0))
    ])
    error_message = "Every proxmox_hosts.vxlan_peer_ipv4 value must be a valid IPv4 address."
  }
}

variable "evpn" {
  description = "Legacy variable name retained for terraform.tfvars compatibility; contains plain VXLAN zone settings only."

  type = object({
    zone_id = string
    mtu     = number
    ipam    = string
  })

  validation {
    condition     = var.evpn.mtu > 0
    error_message = "evpn.mtu must be greater than zero."
  }
}

variable "subnets" {
  description = "Canonical VXLAN VNet and OpenWrt NIC inventory, keyed by VNet ID."

  type = map(object({
    vni            = number
    cidr           = string
    gateway        = string
    snat           = bool
    openwrt_device = string
  }))

  validation {
    condition     = length(var.subnets) > 0
    error_message = "subnets must define at least one VXLAN VNet."
  }

  validation {
    condition = alltrue([
      for subnet in values(var.subnets) :
      can(cidrhost(subnet.cidr, 0))
    ])
    error_message = "Every subnets.cidr value must be valid IPv4 CIDR notation."
  }

  validation {
    condition = alltrue([
      for subnet in values(var.subnets) :
      can(cidrhost("${subnet.gateway}/32", 0))
    ])
    error_message = "Every subnets.gateway value must be a valid IPv4 address."
  }

  validation {
    condition = length(distinct([
      for subnet in values(var.subnets) : subnet.vni
    ])) == length(var.subnets)

    error_message = "Every subnet must have a unique VNI."
  }

  validation {
    condition = length(distinct([
      for subnet in values(var.subnets) : subnet.openwrt_device
    ])) == length(var.subnets)

    error_message = "Each subnet must use a unique openwrt_device such as eth1, eth2, eth3."
  }
}

variable "firewall_rules_prepend" {
  description = "Optional raw OpenWrt UCI firewall fragment prepended to the generated firewall configuration."

  type    = string
  default = ""
}
