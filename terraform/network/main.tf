terraform {
  required_version = ">= 1.6.0"

  required_providers {
    openwrt = {
      source  = "joneshf/openwrt"
      version = "0.0.20"
    }

    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.105"
    }
  }
}

variable "openwrt_ip" {
  description = "Static management IPv4 address of the reachable OpenWrt LuCI RPC endpoint."
  type        = string

  validation {
    condition     = can(cidrhost("${var.openwrt_ip}/32", 0))
    error_message = "openwrt_ip must be a valid IPv4 address."
  }
}

variable "openwrt_username" {
  description = "Username used by the OpenWrt LuCI RPC provider."
  type        = string

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
    error_message = "openwrt_password must not be empty. Set TF_VAR_openwrt_password in ../.env."
  }
}

variable "proxmox_api_endpoint" {
  description = "Proxmox VE API endpoint, for example https://mgmt3:8006."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^https?://", var.proxmox_api_endpoint))
    error_message = "proxmox_api_endpoint must begin with http:// or https://."
  }
}

variable "proxmox_api_token" {
  description = "Proxmox VE API token."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.proxmox_api_token)) > 0
    error_message = "proxmox_api_token must not be empty."
  }
}

variable "proxmox_insecure" {
  description = "Skip TLS certificate verification for the Proxmox VE API."
  type        = bool
  default     = true
}

provider "proxmox" {
  endpoint  = var.proxmox_api_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure
}

output "openwrt_management_url" {
  description = "OpenWrt LuCI RPC endpoint managed by this Terraform root."
  value       = "http://${var.openwrt_ip}:80"
}
