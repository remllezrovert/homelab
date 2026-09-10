terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }

    openwrt = {
      source  = "joneshf/openwrt"
      version = "0.0.20"
    }
  }
}

variable "proxmox_api_endpoint" {
  description = "Proxmox VE API endpoint."
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token."
  type        = string
  sensitive   = true
}

variable "openwrt_root_password" {
  description = "Root password configured in the OpenWrt container."
  type        = string
  sensitive   = true
}

variable "openwrt_ip" {
  description = "Static IPv4 address intended for the OpenWrt container."
  type        = string
  default     = "192.168.2.101"
}

variable "openwrt_username" {
  description = "Username used by the OpenWrt Terraform provider."
  type        = string
  default     = "root"
}

variable "openwrt_password" {
  description = "Password used by the OpenWrt Terraform provider."
  type        = string
  sensitive   = true
}

provider "proxmox" {
  endpoint  = var.proxmox_api_endpoint
  api_token = var.proxmox_api_token
  insecure  = true
}

output "openwrt_container_id" {
  description = "Proxmox LXC container ID for OpenWrt."
  value       = proxmox_virtual_environment_container.openwrt_01.vm_id
}

output "openwrt_container_name" {
  description = "OpenWrt container hostname."
  value       = "openwrt-01"
}
