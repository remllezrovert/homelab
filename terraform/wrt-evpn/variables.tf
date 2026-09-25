# ---------------------------------------------------------------------------
# OpenFabric / EVPN inventory inputs
#
# Values are assigned in terraform.tfvars.
# ---------------------------------------------------------------------------

variable "openfabric" {
  description = "Proxmox OpenFabric underlay configuration."

  type = object({
    id        = string
    ip_prefix = string
  })
}

variable "proxmox_hosts" {
  description = "Proxmox OpenFabric nodes keyed by exact Proxmox node name."

  type = map(object({
    openfabric_ipv4       = string
    openfabric_interfaces = set(string)
  }))

  validation {
    condition     = length(var.proxmox_hosts) > 0
    error_message = "proxmox_hosts must define at least one Proxmox node."
  }

  validation {
    condition = alltrue([
      for host in values(var.proxmox_hosts) :
      can(cidrhost("${host.openfabric_ipv4}/32", 0))
    ])
    error_message = "Every proxmox_hosts.openfabric_ipv4 value must be a valid IPv4 address."
  }
}

variable "evpn" {
  description = "Proxmox EVPN controller and zone settings."

  type = object({
    controller_id              = string
    zone_id                    = string
    asn                        = number
    vrf_vxlan                  = number
    mtu                        = number
    ipam                       = string
    advertise_subnets          = bool
    disable_arp_nd_suppression = bool
    exit_nodes                 = list(string)
    exit_nodes_local_routing   = bool
    primary_exit_node          = string
    rt_import                  = string
  })

  validation {
    condition = alltrue([
      contains(keys(var.proxmox_hosts), var.evpn.primary_exit_node),
      alltrue([
        for node in var.evpn.exit_nodes :
        contains(keys(var.proxmox_hosts), node)
      ]),
    ])
    error_message = "evpn.primary_exit_node and every evpn.exit_nodes entry must exist in proxmox_hosts."
  }
}

variable "subnets" {
  description = "Canonical Proxmox EVPN VNet and OpenWrt NIC inventory, keyed by VNet ID."

  type = map(object({
    vni            = number
    cidr           = string
    gateway        = string
    snat           = bool
    openwrt_device = string
  }))

  validation {
    condition     = length(var.subnets) > 0
    error_message = "subnets must define at least one EVPN VNet."
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
