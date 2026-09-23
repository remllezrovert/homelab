# ---------------------------------------------------------------------------
# Terraform provider requirements
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    # Existing provider used by this root for in-guest OpenWrt UCI state.
    openwrt = {
      source  = "joneshf/openwrt"
      version = "0.0.20"
    }

    # Required by:
    #   - csi-prox.tf
    #   - k8s-worker.tf
    #
    # Supplies proxmox_virtual_environment_* resources.
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.76"
    }
  }
}

# ---------------------------------------------------------------------------
# BPG Proxmox VE provider
#
# Existing .env contract:
#
#   TF_VAR_proxmox_api_endpoint
#   TF_VAR_proxmox_api_token
#   TF_VAR_proxmox_insecure
#
# Terraform automatically maps TF_VAR_<name> into a variable named <name>.
# This retains your current run.sh/.env workflow unchanged.
# ---------------------------------------------------------------------------

variable "proxmox_api_endpoint" {
  description = "Proxmox VE API URL, including https scheme and port 8006."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^https?://", var.proxmox_api_endpoint))
    error_message = "proxmox_api_endpoint must begin with http:// or https://."
  }
}

variable "proxmox_api_token" {
  description = "Proxmox API token formatted as user@realm!token-name=token-secret."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.proxmox_api_token)) > 0
    error_message = "proxmox_api_token must not be empty."
  }
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for the Proxmox VE API endpoint."
  type        = bool
  default     = false
}

provider "proxmox" {
  endpoint  = var.proxmox_api_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure
}

# ---------------------------------------------------------------------------
# OpenWrt provider connection variables
#
# CT 101 itself, its Proxmox NICs, VLAN 12 attachment, EVPN VNet attachments,
# Proxmox SDN gateway configuration, SNAT, DHCP, DNS, and routing are managed
# outside this Terraform root.
#
# This root uses the OpenWrt provider only for in-guest UCI state.
# ---------------------------------------------------------------------------

variable "openwrt_ip" {
  description = "Static management IPv4 address of the reachable OpenWrt LuCI RPC endpoint."
  type        = string
  default     = "192.168.2.2"

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
