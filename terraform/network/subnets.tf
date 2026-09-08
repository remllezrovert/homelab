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
