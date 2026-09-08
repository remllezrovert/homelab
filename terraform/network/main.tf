terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source = "bpg/proxmox"
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
  type      = string
  sensitive = true
}

provider "proxmox" {
  endpoint  = var.proxmox_api_endpoint
  api_token = var.proxmox_api_token
  insecure  = true
}



resource "proxmox_virtual_environment_container" "openwrt" {
  vm_id     = 101
  node_name = "mgmt1"

  description = "OpenWrt network utility: Terraform-managed DHCP/DNS"
  tags        = ["terraform", "openwrt", "net-utils"]

  started       = true
  start_on_boot = true

  unprivileged = false

  operating_system {
    template_file_id = "cephfs:vztmpl/openwrt-25.12.5-x86-64-rootfs.tar.gz"
    type             = "unmanaged"
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 500
    swap      = 0
  }

  disk {
    datastore_id = "proxpool"
    size         = 2
  }

  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    vlan_id = 12
  }

  initialization {
    hostname = "openwrt"

    ip_config {
      ipv4 {
        address = "192.168.2.101/24"
        gateway = "192.168.2.1"
      }
    }
  }
}





output "openwrt_container_id" {
  value = proxmox_virtual_environment_container.openwrt.vm_id
}

output "openwrt_container_name" {
  value = "openwrt-01"
}
