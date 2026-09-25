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
      mac_address = "02:8A:01:02:01:03"
    }
  }
}

resource "openwrt_dhcp_host" "k8s_worker_03" {
  id   = "k8s_worker_03"
  name = "k8s-worker-03"
  mac  = "02:8A:01:02:01:03"
  ip   = "10.8.1.103"
}









resource "proxmox_cloned_vm" "k8s_control_01" {
  id          = 300
  node_name   = "mgmt1"
  name        = "k8s-control-01"
  description = "Kubernetes worker on EVPN VNet k8sctrl (VNI 10001); managed by Terraform."

  tags    = ["terraform", "kubernetes", "worker", "evpn", "k8sctl"]
  started = true

  clone = {
    source_vm_id     = 900
    source_node_name = "mgmt3"
    target_datastore = "proxpool"
    full             = true
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
      mac_address = "02:8A:01:02:01:00"
    }
  }
}

resource "openwrt_dhcp_host" "k8s_control_01" {
  id   = "k8s_control_01"
  name = "k8s-control-01"
  mac  = "02:8A:01:02:01:00"
  ip   = "10.8.0.101"
}
