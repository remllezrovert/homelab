# ---------------------------------------------------------------------------
# Proxmox plain VXLAN / OpenWrt infrastructure
#
# This is the non-secret source of truth for:
# - Proxmox host VXLAN peer addresses
# - Plain VXLAN zone settings
# - VXLAN VNet IDs, VNIs, subnet CIDRs, and OpenWrt gateway addresses
# - OpenWrt CT management identity and VNet NIC assignments
#
# Secrets belong in .env, never here.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Proxmox API
#
# Provide these through .env:
#   TF_VAR_proxmox_api_endpoint
#   TF_VAR_proxmox_api_token
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Proxmox hosts
#
# Map key must be the exact Proxmox node name.
#
# vxlan_peer_ipv4 is the reachable underlay IP for that Proxmox host.
# Every host must be able to reach every other peer over UDP/4789.
# ---------------------------------------------------------------------------

proxmox_hosts = {
  mgmt1 = {
    vxlan_peer_ipv4 = "192.168.1.11"
  }

  mgmt2 = {
    vxlan_peer_ipv4 = "192.168.1.12"
  }

  mgmt3 = {
    vxlan_peer_ipv4 = "192.168.1.13"
  }
}

# ---------------------------------------------------------------------------
# Plain VXLAN zone
#
# It no longer contains EVPN controller, exit-node, ASN, VRF, or route-target
# settings.
# ---------------------------------------------------------------------------

vxlan = {
  zone_id = "vxlan"
  mtu     = 1450
  ipam    = "pve"
}

# ---------------------------------------------------------------------------
# VXLAN VNets and OpenWrt router interfaces
#
# gateway is the OpenWrt address on that VNet.
# Proxmox does not own these gateway addresses and does not perform SNAT.
# ---------------------------------------------------------------------------

subnets = {
  k8sctl = {
    vni            = 10001
    cidr           = "10.8.0.0/24"
    gateway        = "10.8.0.2"
    snat           = true
    openwrt_device = "eth1"
  }

  k8swrk = {
    vni            = 10002
    cidr           = "10.8.1.0/24"
    gateway        = "10.8.1.2"
    snat           = true
    openwrt_device = "eth2"
  }

  k8sfun = {
    vni            = 10003
    cidr           = "10.8.2.0/24"
    gateway        = "10.8.2.2"
    snat           = true
    openwrt_device = "eth3"
  }
}

# ---------------------------------------------------------------------------
# OpenWrt firewall policy
#
# Workers may initiate Kubernetes API access to the control plane at
# 10.8.0.101:6443 through OpenWrt's k8sctl interface at 10.8.0.2.
# ---------------------------------------------------------------------------

firewall_rules_prepend = <<-UCI
config forwarding 'k8swrk_to_k8sctl'
        option src 'k8swrk'
        option dest 'k8sctl'

config rule 'allow_k8swrk_to_k8sctl_api'
        option name 'Allow Kubernetes workers to Kubernetes API'
        option src 'k8swrk'
        option dest 'k8sctl'
        option dest_ip '10.8.0.101'
        option proto 'tcp'
        option dest_port '6443'
        option target 'ACCEPT'

config rule 'allow_lan_to_k8s_api'
        option name 'Allow management host to Kubernetes API'
        option src 'lan'
        option src_ip '192.168.2.2'
        option dest 'k8sctl'
        option dest_ip '10.8.0.101'
        option proto 'tcp'
        option dest_port '6443'
        option target 'ACCEPT'

config rule 'allow_lan_to_k8s_worker_ssh'
        option name 'Allow management host to Kubernetes worker SSH'
        option src 'lan'
        option src_ip '192.168.2.2'
        option dest 'k8swrk'
        option dest_ip '10.8.1.0/24'
        option proto 'tcp'
        option dest_port '22'
        option target 'ACCEPT'
UCI



# ---------------------------------------------------------------------------
# OpenWrt CT management configuration
# ---------------------------------------------------------------------------

dns_domain = "remllez.local"
openwrt_ip = "192.168.2.2"
openwrt_username = "root"

openwrt_management_network = {
  cidr    = "192.168.2.0/24"
  gateway = "192.168.2.1"
  dns     = ["192.168.2.1"]
}
