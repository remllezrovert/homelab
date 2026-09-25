# ---------------------------------------------------------------------------
# Proxmox OpenFabric / EVPN / OpenWrt infrastructure
# This is the non-secret source of truth for:
# - Proxmox OpenFabric nodes
# - EVPN controller and zone behavior
# - EVPN VNet IDs, VNIs, subnet CIDRs, gateways, and SNAT
# - OpenWrt CT management identity and EVPN NIC assignments
# Secrets belong in .env, never here.

# ---------------------------------------------------------------------------
# Proxmox API
# `proxmox_api_endpoint` and `proxmox_api_token` should normally come from:
#   TF_VAR_proxmox_api_endpoint
#   TF_VAR_proxmox_api_token
# in .env. Do not duplicate credentials here.

# ---------------------------------------------------------------------------
# OpenFabric underlay

openfabric = {
  id        = "main"
  ip_prefix = "10.0.0.0/16"
}

# ---------------------------------------------------------------------------
# Proxmox hosts
#
# Map key must be the exact Proxmox node name.
#
# `openfabric_ipv4` is the OpenFabric router address on that host.
# `openfabric_interfaces` must contain real, existing host interfaces.
# ---------------------------------------------------------------------------

proxmox_hosts = {
  mgmt1 = {
    openfabric_ipv4       = "10.0.0.11"
    openfabric_interfaces = ["vmbr0"]
  }

  mgmt2 = {
    openfabric_ipv4       = "10.0.0.12"
    openfabric_interfaces = ["vmbr0"]
  }

  mgmt3 = {
    openfabric_ipv4       = "10.0.0.13"
    openfabric_interfaces = ["vmbr0"]
  }
}

# ---------------------------------------------------------------------------
# EVPN controller and zone
# ---------------------------------------------------------------------------

evpn = {
  controller_id = "evpn1"
  zone_id       = "evpn"

  asn       = 65000
  vrf_vxlan = 4000
  mtu       = 1450
  ipam      = "pve"

  advertise_subnets          = true
  disable_arp_nd_suppression = false

  # PVE EVPN exit-node policy.
  #
  # mgmt1 supplies routed/SNAT egress for EVPN subnets where snat = true.
  exit_nodes               = ["mgmt1"]
  exit_nodes_local_routing = true
  primary_exit_node        = "mgmt1"

  rt_import = "65000:65000"
}

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
# OpenWrt CT management configuration
#
# ---------------------------------------------------------------------------
dns_domain = "remllez.local"
openwrt_ip       = "192.168.2.2"
openwrt_username = "root"

openwrt_management_network = {
  cidr    = "192.168.2.0/24"
  gateway = "192.168.2.1"
  dns     = ["192.168.2.1"]
}
