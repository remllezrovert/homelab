terraform {
  required_version = ">= 1.6.0"

  required_providers {
    openwrt = {
      source  = "joneshf/openwrt"
      version = "0.0.20"
    }
  }
}

# ---------------------------------------------------------------------------
# OpenWrt provider connection variables
#
# CT 101 itself, its Proxmox NICs, VLAN 12 attachment, EVPN VNet attachments,
# Proxmox SDN gateway configuration, and SNAT are managed by infra-network.
#
# This config-network Terraform root manages in-guest OpenWrt UCI state only.
# ---------------------------------------------------------------------------

variable "openwrt_ip" {
  description = "Static management IPv4 address of the reachable OpenWrt LuCI RPC endpoint."
  type        = string
  default     = "192.168.2.101"

  validation {
    condition     = can(cidrhost("${var.openwrt_ip}/32", 0))
    error_message = "openwrt_ip must be a valid IPv4 address."
  }
}

variable "openwrt_username" {
  description = "Username used by the OpenWrt LuCI RPC provider."
  type        = string
  default     = "root"

  validation {
    condition     = length(trimspace(var.openwrt_username)) > 0
    error_message = "openwrt_username must not be empty."
  }
}

variable "openwrt_password" {
  description = "Password used by the OpenWrt LuCI RPC provider."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.openwrt_password) > 0
    error_message = "openwrt_password must not be empty."
  }
}

output "openwrt_management_url" {
  description = "OpenWrt LuCI RPC endpoint managed by this Terraform root."
  value       = "http://${var.openwrt_ip}:80"
}
