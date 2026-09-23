resource "proxmox_virtual_environment_role" "kubernetes_csi" {
  role_id = "Kubernetes-CSI"

  privileges = [
    "VM.Audit",
    "VM.Config.Disk",

    "Datastore.Audit",
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
  ]
}

resource "proxmox_virtual_environment_user" "kubernetes_csi" {
  user_id = "kubernetes-csi@pve"
  comment = "Kubernetes Proxmox CSI driver; managed by Terraform."

  acl {
    path      = "/"
    role_id   = proxmox_virtual_environment_role.kubernetes_csi.role_id
    propagate = true
  }
}

resource "proxmox_virtual_environment_user_token" "kubernetes_csi" {
  user_id    = proxmox_virtual_environment_user.kubernetes_csi.user_id
  token_name = "csi"
  comment    = "Proxmox CSI driver token; managed by Terraform."

  # The CSI documentation's CLI example uses a non-privilege-separated
  # token. The token inherits the CSI user's ACLs.
  privileges_separation = false
}
