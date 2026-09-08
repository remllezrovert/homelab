# ---------------------------------------------------------------------------
# EVPN VNet subnet services
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
# Do not configure dhcp_range or dhcp_dns_server here. Doing so would
# create a second DHCP/DNS authority on the same L2 broadcast domains.
# ---------------------------------------------------------------------------

# Kubernetes control-plane network:
# VNet:    k8sctl
# Subnet:  10.8.0.0/24
# Gateway: 10.8.0.1 (Proxmox SDN)
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
# Gateway: 10.8.1.1 (Proxmox SDN)
# DHCP/DNS: OpenWrt at 10.8.1.101
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
# Apply EVPN subnet/gateway/SNAT configuration before CT 101 connects.
# ---------------------------------------------------------------------------

resource "proxmox_sdn_applier" "subnet_applier" {
  depends_on = [
    proxmox_sdn_subnet.k8s_control,
    proxmox_sdn_subnet.k8s_workers,
  ]
}

# ---------------------------------------------------------------------------
# OpenWrt provider
#
# Management API endpoint:
# http://192.168.2.101:80
# ---------------------------------------------------------------------------

provider "openwrt" {
  hostname = var.openwrt_ip
  username = var.openwrt_username
  password = var.openwrt_password
  scheme   = "http"
  port     = 80
}

# ---------------------------------------------------------------------------
# OpenWrt CT 101
#
# eth0: vmbr0 access VLAN 12 -> 192.168.2.101/24
# eth1: k8sctl EVPN VNet     -> 10.8.0.101/24
# eth2: k8swrk EVPN VNet     -> 10.8.1.101/24
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
    vm_id        = 904
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

  # Management network. Proxmox applies VLAN 12; OpenWrt sees eth0
  # as an untagged interface inside CT 101.
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

    # Proxmox LXC primary-interface metadata only. The OpenWrt provider
    # owns actual in-guest UCI interface configuration.
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

# ---------------------------------------------------------------------------
# OpenWrt UCI network interfaces
#
# OpenWrt CT 101:
#   mgmt   -> eth0 -> 192.168.2.101/24 -> default gateway 192.168.2.1
#   k8sctl -> eth1 -> 10.8.0.101/24
#   k8swrk -> eth2 -> 10.8.1.101/24
#
# No br-lan device is declared here.
# ---------------------------------------------------------------------------

resource "openwrt_network_interface" "mgmt" {
  id     = "mgmt"
  device = "eth0"
  proto  = "static"

  ipaddr  = var.openwrt_ip
  netmask = "255.255.255.0"
  gateway = "192.168.2.1"

  dns = [
    "192.168.2.1",
  ]

  depends_on = [
    proxmox_virtual_environment_container.openwrt_01,
  ]
}

resource "openwrt_network_interface" "k8sctl" {
  id     = "k8sctl"
  device = "eth1"
  proto  = "static"

  ipaddr  = "10.8.0.101"
  netmask = "255.255.255.0"

  depends_on = [
    proxmox_virtual_environment_container.openwrt_01,
    proxmox_sdn_applier.subnet_applier,
  ]
}

resource "openwrt_network_interface" "k8swrk" {
  id     = "k8swrk"
  device = "eth2"
  proto  = "static"

  ipaddr  = "10.8.1.101"
  netmask = "255.255.255.0"

  depends_on = [
    proxmox_virtual_environment_container.openwrt_01,
    proxmox_sdn_applier.subnet_applier,
  ]
}
