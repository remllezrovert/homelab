# ---------------------------------------------------------------------------
# Deploy OpenWrt firewall policy
#
# firewall_rules_prepend:
#   Optional raw UCI sections supplied from the shared terraform.tfvars file.
#   They are rendered before firewall.uci.tftpl so narrow explicit ACCEPT rules
#   can precede the generated RFC1918/special-use IPv4 REJECT rules.
#
# firewall.uci.tftpl:
#   Generated zone, forwarding, and egress-isolation policy rendered from
#   var.subnets.
#
# The complete rendered UCI configuration is staged to OpenWrt, validated with
# `fw4 check`, then atomically installed as /etc/config/firewall before fw4 is
# restarted. If validation fails, the previous file is restored and restarted.
#
# `scp -O` forces legacy SCP protocol for Dropbear systems without SFTP.
# ---------------------------------------------------------------------------

locals {
  openwrt_firewall_generated_uci = templatefile(
    "${path.module}/firewall.uci.tftpl",
    {
      subnets = var.subnets
    },
  )

  openwrt_firewall_prepend_uci = trimspace(var.firewall_rules_prepend)

  openwrt_firewall_uci = join(
    "\n\n",
    compact([
      local.openwrt_firewall_prepend_uci,
      trimspace(local.openwrt_firewall_generated_uci),
    ]),
  )

  openwrt_firewall_uci_sha256 = sha256(local.openwrt_firewall_uci)
}

resource "terraform_data" "openwrt_firewall" {
  triggers_replace = [
    local.openwrt_firewall_uci_sha256,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    environment = {
      SSHPASS = var.openwrt_password
    }

    command = <<-EOT
      set -euo pipefail

      local_file="$(mktemp)"
      remote_file="/tmp/firewall.new"
      remote_backup="/tmp/firewall.previous"

      cleanup() {
        rm -f "$local_file"
      }

      trap cleanup EXIT

      cat > "$local_file" <<'FIREWALL_UCI'
${local.openwrt_firewall_uci}
FIREWALL_UCI

      sshpass -e scp -O \
        -o BatchMode=no \
        -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=10 \
        -o ServerAliveInterval=5 \
        -o ServerAliveCountMax=3 \
        -P 22 \
        "$local_file" \
        "${var.openwrt_username}@${var.openwrt_ip}:$remote_file"

      sshpass -e ssh \
        -o BatchMode=no \
        -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=10 \
        -o ServerAliveInterval=5 \
        -o ServerAliveCountMax=3 \
        -p 22 \
        "${var.openwrt_username}@${var.openwrt_ip}" \
        "set -eu
         test -s '$remote_file'
         cp /etc/config/firewall '$remote_backup'
         cp '$remote_file' /etc/config/firewall
         rm -f '$remote_file'

         if fw4 check; then
           /etc/init.d/firewall restart
           rm -f '$remote_backup'
         else
           cp '$remote_backup' /etc/config/firewall
           rm -f '$remote_backup'
           /etc/init.d/firewall restart
           exit 1
         fi"
    EOT
  }

  depends_on = [
    openwrt_network_interface.lan,
    openwrt_network_interface.subnet,
  ]
}
