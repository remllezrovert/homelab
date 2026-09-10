# ---------------------------------------------------------------------------
# EVPN VNet subnet services and OpenWrt container
#
# Proxmox SDN owns:
# - EVPN/VNet connectivity
# - Gateway addresses
# - SNAT through EVPN exit nodes
#
# OpenWrt CT 101 owns:
# - DHCP lease service
# - DNS service
#
# OpenWrt UCI configuration is intentionally kept in openwrt.tf.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# EVPN subnets
# ---------------------------------------------------------------------------

# Kubernetes control-plane network:
# VNet:    k8sctl
# Subnet:  10.8.0.0/24
# Gateway: 10.8.0.1 (openwrt)
# DHCP/DNS: OpenWrt at 10.8.0.101
resource "proxmox_sdn_subnet" "k8s_control" {
  vnet    = proxmox_sdn_vnet.k8s_control.id
  cidr    = "10.8.0.0/24"
  gateway = "10.8.0.1"
  snat    = true

  depends_on = [
    proxmox_sdn_vnet.k8s_control,
  ]
}

# Kubernetes worker network:
# VNet:    k8swrk
# Subnet:  10.8.1.0/24
# Gateway: 10.8.1.1 (openwrt) 
# DHCP/DNS: OpenWrt at 10.8.1.1
resource "proxmox_sdn_subnet" "k8s_workers" {
  vnet    = proxmox_sdn_vnet.k8s_workers.id
  cidr    = "10.8.1.0/24"
  gateway = "10.8.1.1"
  snat    = true

  depends_on = [
    proxmox_sdn_vnet.k8s_workers,
  ]
}

# ---------------------------------------------------------------------------
# Apply EVPN subnet, gateway, and SNAT configuration before CT 101 connects.
# ---------------------------------------------------------------------------

resource "proxmox_sdn_applier" "subnet_applier" {
  depends_on = [
    proxmox_sdn_subnet.k8s_control,
    proxmox_sdn_subnet.k8s_workers,
  ]
}

# ---------------------------------------------------------------------------
# OpenWrt CT 101 infrastructure
#
# eth0: vmbr0 access VLAN 12 -> 192.168.2.101/24
# eth1: k8sctl EVPN VNet     -> 10.8.0.101/24
# eth2: k8swrk EVPN VNet     -> 10.8.1.101/24
#
# The Proxmox provider owns the LXC lifecycle and NIC attachments.
# The OpenWrt provider owns in-guest UCI configuration in openwrt.tf.
# ---------------------------------------------------------------------------

resource "proxmox_virtual_environment_container" "openwrt_01" {
  vm_id     = 101
  node_name = "mgmt1"

  description = "OpenWrt DHCP/DNS server for k8sctl and k8swrk EVPN VNets"
  tags        = ["terraform", "openwrt", "dns", "dhcp", "net-utils"]

  started       = true
  start_on_boot = true
  unprivileged  = false

  clone {
    vm_id        = 905
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

  # Management network.
  #
  # Proxmox applies VLAN 12 on vmbr0. OpenWrt sees eth0 as an
  # untagged interface within the container.
  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    vlan_id = 12
  }

  # Kubernetes control-plane EVPN VNet.
  network_interface {
    name   = "eth1"
    bridge = proxmox_sdn_vnet.k8s_control.id
  }

  # Kubernetes worker EVPN VNet.
  network_interface {
    name   = "eth2"
    bridge = proxmox_sdn_vnet.k8s_workers.id
  }

  initialization {
    hostname = "openwrt-01"

    # This supplies Proxmox LXC primary-interface metadata and establishes
    # initial management connectivity. In-guest UCI configuration is managed
    # by the OpenWrt provider in openwrt.tf.
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
