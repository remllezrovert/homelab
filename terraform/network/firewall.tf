# ---------------------------------------------------------------------------
# Cluster firewall options
#
# Keep the default forwarding policy ACCEPT while validating OpenFabric and
# EVPN. This ensures the Proxmox firewall does not block unrelated LAN/VPN/
# EVPN forwarding paths.
# ---------------------------------------------------------------------------

resource "proxmox_virtual_environment_cluster_firewall" "main" {
  enabled        = true
  input_policy   = "ACCEPT"
  output_policy  = "ACCEPT"
  forward_policy = "ACCEPT"
}

# ---------------------------------------------------------------------------
# Cluster firewall IP sets
#
# These are traffic-match selectors only. They do not create VNet subnets,
# VNet gateways, DHCP, routing, or SNAT.
# ---------------------------------------------------------------------------

resource "proxmox_virtual_environment_firewall_ipset" "k8s_control" {
  name    = "k8s_control"
  comment = "Kubernetes control-plane subnet"

  cidr {
    name    = "10.8.0.0/24"
    comment = "Kubernetes control-plane network"
  }
}

resource "proxmox_virtual_environment_firewall_ipset" "k8s_workers" {
  name    = "k8s_workers"
  comment = "Kubernetes worker subnet"

  cidr {
    name    = "10.8.1.0/24"
    comment = "Kubernetes worker network"
  }
}

# ---------------------------------------------------------------------------
# Cluster forwarding rules
#
# These rules become relevant if you later change forward_policy to DROP.
# With forward_policy = ACCEPT, they are explicit documentation and do not
# block other traffic.
# ---------------------------------------------------------------------------

resource "proxmox_virtual_environment_firewall_rules" "k8s_forward" {
  depends_on = [
    proxmox_virtual_environment_cluster_firewall.main,
    proxmox_virtual_environment_firewall_ipset.k8s_control,
    proxmox_virtual_environment_firewall_ipset.k8s_workers,
  ]

  rule {
    type    = "forward"
    action  = "ACCEPT"
    source  = "+k8s_workers"
    dest    = "+k8s_control"
    proto   = "tcp"
    dport   = "6443"
    comment = "Kubernetes workers to control-plane API"
  }

  rule {
    type    = "forward"
    action  = "ACCEPT"
    source  = "+k8s_control"
    dest    = "+k8s_workers"
    comment = "Kubernetes control-plane to workers"
  }

  rule {
    type    = "forward"
    action  = "ACCEPT"
    source  = "+k8s_workers"
    dest    = "+k8s_workers"
    comment = "Kubernetes worker-to-worker traffic"
  }
}
