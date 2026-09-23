# ---------------------------------------------------------------------------

# Proxmox VM identity.
k8s_worker_name = "k8s-worker-01"
k8s_worker_vmid = 301

# Initial VM placement.
k8s_worker_proxmox_node = "mgmt3"

# Existing cloud-init VM template.
k8s_worker_template_vmid = 900

# Storage used for the full clone and its cloud-init disk.
k8s_worker_datastore_id           = "proxpool"
k8s_worker_cloudinit_datastore_id = "proxpool"

# Static identity on the pre-existing k8swrk EVPN VNet.
k8s_worker_ipv4_address = "10.8.1.101/24"

# OpenWrt is the L3 router, firewall, DHCP server, and DNS resolver for
# the worker segment.
k8s_worker_ipv4_gateway = "10.8.1.2"
k8s_worker_dns_servers  = ["10.8.1.2"]
k8s_worker_dns_domain   = "remllez.com"

# Kubernetes node sizing.
k8s_worker_cpu_cores = 4
k8s_worker_memory_mb = 8192
