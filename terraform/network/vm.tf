# ---------------------------------------------------------------------------
# Kubernetes virtual machines and OpenWrt DHCP reservations.
#
# All VMs clone from template 900. The boot disk is explicitly set to 40 GiB
# so Kubernetes, containerd images, etcd, package caches, and logs do not
# inherit the tiny cloud-image root disk size.
# ---------------------------------------------------------------------------

resource "proxmox_cloned_vm" "k8s_worker_01" {
  id          = 301
  node_name   = "mgmt1"
  name        = "k8s-worker-01"
  description = "Kubernetes worker on EVPN VNet k8swrk (VNI 10002); managed by Terraform."

  tags    = ["terraform", "kubernetes", "worker", "evpn", "k8swrk"]
  started = true

  clone = {
    source_vm_id     = 900
    source_node_name = "mgmt3"
    target_datastore = "proxpool"
    full             = true
  }

  disk = {
    scsi0 = {
      datastore_id = "proxpool"
      size_gb      = 40
      discard      = "on"
      ssd          = true
    }
  }

  cpu = {
    cores = 4
    type  = "host"
  }

  memory = {
    size    = 8192
    balloon = 0
  }

  network = {
    net0 = {
      bridge      = "k8swrk"
      model       = "virtio"
      mac_address = "02:8A:01:02:01:01"
    }
  }
}

resource "openwrt_dhcp_host" "k8s_worker_01" {
  id   = "k8s_worker_01"
  name = "k8s-worker-01"
  mac  = "02:8A:01:02:01:01"
  ip   = "10.8.1.101"
}

resource "proxmox_cloned_vm" "k8s_worker_02" {
  id          = 302
  node_name   = "mgmt2"
  name        = "k8s-worker-02"
  description = "Kubernetes worker on EVPN VNet k8swrk (VNI 10002); managed by Terraform."

  tags    = ["terraform", "kubernetes", "worker", "evpn", "k8swrk"]
  started = true

  clone = {
    source_vm_id     = 900
    source_node_name = "mgmt3"
    target_datastore = "proxpool"
    full             = true
  }

  disk = {
    scsi0 = {
      datastore_id = "proxpool"
      size_gb      = 40
      discard      = "on"
      ssd          = true
    }
  }

  cpu = {
    cores = 4
    type  = "host"
  }

  memory = {
    size    = 8192
    balloon = 0
  }

  network = {
    net0 = {
      bridge      = "k8swrk"
      model       = "virtio"
      mac_address = "02:8A:01:02:01:02"
    }
  }
}

resource "openwrt_dhcp_host" "k8s_worker_02" {
  id   = "k8s_worker_02"
  name = "k8s-worker-02"
  mac  = "02:8A:01:02:01:02"
  ip   = "10.8.1.102"
}

resource "proxmox_cloned_vm" "k8s_worker_03" {
  id          = 303
  node_name   = "mgmt3"
  name        = "k8s-worker-03"
  description = "Kubernetes worker on EVPN VNet k8swrk (VNI 10002); managed by Terraform."

  tags    = ["terraform", "kubernetes", "worker", "evpn", "k8swrk"]
  started = true

  clone = {
    source_vm_id     = 900
    source_node_name = "mgmt3"
    target_datastore = "proxpool"
    full             = true
  }

  disk = {
    scsi0 = {
      datastore_id = "proxpool"
      size_gb      = 40
      discard      = "on"
      ssd          = true
    }
  }

  cpu = {
    cores = 4
    type  = "host"
  }

  memory = {
    size    = 8192
    balloon = 0
  }

  network = {
    net0 = {
      bridge      = "k8swrk"
      model       = "virtio"
      mac_address = "02:8A:01:02:01:33"
    }
  }
}

resource "openwrt_dhcp_host" "k8s_worker_03" {
  id   = "k8s_worker_03"
  name = "k8s-worker-03"
  mac  = "02:8A:01:02:01:33"
  ip   = "10.8.1.103"
}

resource "proxmox_cloned_vm" "k8s_control_01" {
  id          = 300
  node_name   = "mgmt1"
  name        = "k8s-control-01"
  description = "Kubernetes control plane on EVPN VNet k8sctl (VNI 10001); managed by Terraform."

  tags    = ["terraform", "kubernetes", "control-plane", "evpn", "k8sctl"]
  started = true

  clone = {
    source_vm_id     = 900
    source_node_name = "mgmt3"
    target_datastore = "proxpool"
    full             = true
  }

  disk = {
    scsi0 = {
      datastore_id = "proxpool"
      size_gb      = 40
      discard      = "on"
      ssd          = true
    }
  }

  cpu = {
    cores = 2
    type  = "host"
  }

  memory = {
    size    = 2048
    balloon = 0
  }

  network = {
    net0 = {
      bridge      = "k8sctl"
      model       = "virtio"
      mac_address = "02:8A:01:02:02:01"
    }
  }
}

resource "openwrt_dhcp_host" "k8s_control_01" {
  id   = "k8s_control_01"
  name = "k8s-control-01"
  mac  = "02:8A:01:02:02:01"
  ip   = "10.8.0.101"
}
