# ---------------------------------------------------------------------------
# Kubernetes worker VM: k8s-worker-01
#
variable "k8s_worker_name" {
  description = "Proxmox VM name and guest hostname."
  type        = string
}

variable "k8s_worker_vmid" {
  description = "Explicit unused Proxmox VMID assigned to this worker."
  type        = number
}

variable "k8s_worker_proxmox_node" {
  description = "Exact Proxmox node name used to create the worker VM."
  type        = string
}

variable "k8s_worker_template_vmid" {
  description = "Existing cloud-init VM template used as the clone source."
  type        = number
  default     = 900
}

variable "k8s_worker_datastore_id" {
  description = "Target Proxmox datastore for the full-cloned root disk."
  type        = string
}

variable "k8s_worker_cloudinit_datastore_id" {
  description = "Proxmox datastore used for the generated cloud-init disk."
  type        = string
}

variable "k8s_worker_ipv4_address" {
  description = "Static worker IPv4 address in CIDR notation on 10.8.1.0/24."
  type        = string

  validation {
    condition     = can(cidrhost(var.k8s_worker_ipv4_address, 0))
    error_message = "k8s_worker_ipv4_address must be valid IPv4 CIDR notation, for example 10.8.1.101/24."
  }
}

variable "k8s_worker_ipv4_gateway" {
  description = "OpenWrt default gateway for the k8swrk worker network."
  type        = string
  default     = "10.8.1.2"

  validation {
    condition     = can(cidrhost("${var.k8s_worker_ipv4_gateway}/32", 0))
    error_message = "k8s_worker_ipv4_gateway must be a valid IPv4 address."
  }
}

variable "k8s_worker_dns_servers" {
  description = "DNS resolver IPs supplied to cloud-init. OpenWrt is authoritative for workers."
  type        = list(string)
  default     = ["10.8.1.2"]

  validation {
    condition     = length(var.k8s_worker_dns_servers) > 0
    error_message = "k8s_worker_dns_servers must contain at least one DNS resolver."
  }
}

variable "k8s_worker_dns_domain" {
  description = "DNS search domain supplied to the worker through cloud-init."
  type        = string
  default     = "remllez.com"
}

variable "k8s_worker_cpu_cores" {
  description = "Number of vCPU cores assigned to the Kubernetes worker."
  type        = number
  default     = 4

  validation {
    condition     = var.k8s_worker_cpu_cores >= 2
    error_message = "k8s_worker_cpu_cores must be at least 2."
  }
}

variable "k8s_worker_memory_mb" {
  description = "Fixed worker RAM allocation in MiB."
  type        = number
  default     = 8192

  validation {
    condition     = var.k8s_worker_memory_mb >= 4096
    error_message = "k8s_worker_memory_mb must be at least 4096 MiB."
  }
}

resource "proxmox_virtual_environment_vm" "k8s_worker_01" {
  name        = var.k8s_worker_name
  description = "Kubernetes worker on EVPN VNet k8swrk (VNI 10002); managed by Terraform."
  node_name   = var.k8s_worker_proxmox_node
  vm_id       = var.k8s_worker_vmid

  tags = [
    "terraform",
    "kubernetes",
    "worker",
    "evpn",
    "k8swrk",
  ]

  # Full clone creates an independent VM/root disk and never modifies
  # source template VMID 900.
  clone {
    vm_id        = var.k8s_worker_template_vmid
    datastore_id = var.k8s_worker_datastore_id
    full         = true
  }

  started = true
  on_boot = true

  # Requires qemu-guest-agent to exist and be enabled inside template 900.
  agent {
    enabled = true
  }

  cpu {
    cores = var.k8s_worker_cpu_cores
    type  = "host"
  }

  # Disable ballooning by fixing the minimum and dedicated allocation equally.
  # This provides predictable allocatable capacity for Kubernetes.
  memory {
    dedicated = var.k8s_worker_memory_mb
    floating  = var.k8s_worker_memory_mb
  }

  # The boot disk is inherited from template 900. Do not declare a disk block
  # until you verify its existing disk interface and want Terraform to manage a
  # deliberate resize:
  #
  #   qm config 900

  # Existing Proxmox SDN EVPN VNet attachment.
  #
  # k8swrk maps to VNI 10002 in the separately managed Proxmox SDN config.
  # There is intentionally no vmbr0 and no vlan_id here.
  network_device {
    bridge = "k8swrk"
    model  = "virtio"
  }

  # Proxmox built-in cloud-init network settings only.
  #
  # No user_account block:
  # template 900 owns the user/password/SSH-key account state.
  initialization {
    datastore_id = var.k8s_worker_cloudinit_datastore_id

    ip_config {
      ipv4 {
        address = var.k8s_worker_ipv4_address
        gateway = var.k8s_worker_ipv4_gateway
      }
    }

    dns {
      servers = var.k8s_worker_dns_servers
      domain  = var.k8s_worker_dns_domain
    }
  }
}

output "k8s_worker_01" {
  description = "Kubernetes worker VM inventory and EVPN identity."
  value = {
    name      = proxmox_virtual_environment_vm.k8s_worker_01.name
    vmid      = proxmox_virtual_environment_vm.k8s_worker_01.vm_id
    node      = proxmox_virtual_environment_vm.k8s_worker_01.node_name
    vnet      = "k8swrk"
    vni       = 10002
    ipv4_cidr = var.k8s_worker_ipv4_address
    gateway   = var.k8s_worker_ipv4_gateway
    dns       = var.k8s_worker_dns_servers
  }
}
