# ---------------------------------------------------------------------------
# EVPN VNet subnet services
#
# Each subnet defines:
# - L3 gateway for its VNet
# - DHCP lease pool
# - DNS server handed to DHCP clients
# - SNAT for stateful outbound access through EVPN exit nodes
#
# The DHCP DNS address must be inside its VNet subnet. Using the VNet gateway
# lets Proxmox SDN dnsmasq provide DNS to guests and forward requests via the
# Proxmox node's configured upstream DNS resolver(s).
# ---------------------------------------------------------------------------

# Kubernetes control-plane network:
# VNet:    k8sctl
# Subnet:  10.8.0.0/24
# Gateway: 10.8.0.1
resource "proxmox_sdn_subnet" "k8s_control" {
  vnet    = proxmox_sdn_vnet.k8s_control.id
  cidr    = "10.8.0.0/24"
  gateway = "10.8.0.1"
  snat    = true

  dhcp_dns_server = "10.8.0.1"

  dhcp_range = {
    start_address = "10.8.0.50"
    end_address   = "10.8.0.200"
  }

  depends_on = [
    proxmox_sdn_vnet.k8s_control,
  ]
}

# Kubernetes worker network:
# VNet:    k8swrk
# Subnet:  10.8.1.0/24
# Gateway: 10.8.1.1
resource "proxmox_sdn_subnet" "k8s_workers" {
  vnet    = proxmox_sdn_vnet.k8s_workers.id
  cidr    = "10.8.1.0/24"
  gateway = "10.8.1.1"
  snat    = true

  dhcp_dns_server = "10.8.1.1"

  dhcp_range = {
    start_address = "10.8.1.50"
    end_address   = "10.8.1.200"
  }

  depends_on = [
    proxmox_sdn_vnet.k8s_workers,
  ]
}

# ---------------------------------------------------------------------------
# Apply newly added subnet, DHCP, DNS, gateway, and SNAT configuration.
# ---------------------------------------------------------------------------

resource "proxmox_sdn_applier" "subnet_applier" {
  depends_on = [
    proxmox_sdn_subnet.k8s_control,
    proxmox_sdn_subnet.k8s_workers,
  ]
}


provider "openwrt" {
  hostname = var.openwrt_ip
  username = var.openwrt_username
  password = var.openwrt_password
  scheme   = "http"
  port     = 80
}

resource "proxmox_virtual_environment_container" "openwrt_01" {
  vm_id     = 101
  node_name = "mgmt1"

  description = "OpenWrt network utility with access to management, k8sctl, and k8swrk networks"
  tags        = ["terraform", "openwrt", "net-utils"]

  # Leave this true only if CT 903 is already proven to boot with its
  # correct in-guest UCI networking. Otherwise it must remain false until
  # OpenWrt guest config is applied through its own provider.
  started       = true
  start_on_boot = true
  unprivileged  = false

  clone {
    vm_id        = 903
    node_name    = "mgmt1"
    datastore_id = "proxpool"
    full         = true
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

  # Management network: physical bridge access VLAN 12.
  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    vlan_id = 12
  }

  # Proxmox SDN EVPN VNet: Kubernetes control-plane network.
  network_interface {
    name   = "eth1"
    bridge = proxmox_sdn_vnet.k8s_control.id
  }

  # Proxmox SDN EVPN VNet: Kubernetes worker network.
  network_interface {
    name   = "eth2"
    bridge = proxmox_sdn_vnet.k8s_workers.id
  }

  initialization {
    hostname = "openwrt-01"

    # Management interface only.
    #
    # This describes the Proxmox LXC metadata. It does not replace
    # OpenWrt UCI configuration; the OpenWrt provider resources below
    # are responsible for in-guest interface state.
    ip_config {
      ipv4 {
        address = "${var.openwrt_ip}/24"
        gateway = "192.168.2.1"
      }
    }
  }

  depends_on = [
    proxmox_sdn_applier.subnet_applier,
  ]
}
