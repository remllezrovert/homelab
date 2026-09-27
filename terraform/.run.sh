#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

infra_dir="${script_dir}/wrt-evpn"
config_dir="${script_dir}/network"
variables_file="${script_dir}/terraform.tfvars"

if [[ ! -f "${script_dir}/.env" ]]; then
  echo "ERROR: Missing ${script_dir}/.env" >&2
  exit 1
fi

if [[ ! -f "${variables_file}" ]]; then
  echo "ERROR: Missing ${variables_file}" >&2
  exit 1
fi

set -a
source "${script_dir}/.env"
set +a

clear_k8s_known_hosts() {
  echo
  echo "=== Clear Kubernetes SSH known-host entries ==="

  awk '
    /^resource "openwrt_dhcp_host"/ {
      in_dhcp = 1
    }

    in_dhcp && /^[[:space:]]*ip[[:space:]]*=/ {
      line = $0
      sub(/^[^"]*"/, "", line)
      sub(/".*$/, "", line)
      print line
    }

    in_dhcp && /^[[:space:]]*}/ {
      in_dhcp = 0
    }
  ' "${config_dir}"/*.tf |
  while IFS= read -r ip; do
    ssh-keygen -R "$ip" -f "$HOME/.ssh/known_hosts" >/dev/null 2>&1 || true
  done
}

run_terraform_root() {
  local root_name="$1"
  local root_dir="$2"
  local action="$3"
  local plan_file="tfplan"

  if [[ ! -d "${root_dir}" ]]; then
    echo "ERROR: Missing Terraform directory: ${root_dir}" >&2
    exit 1
  fi

  rm -f "${root_dir}/${plan_file}"

  echo
  echo "=== ${root_name}: Format ==="
  terraform -chdir="${root_dir}" fmt

  echo
  echo "=== ${root_name}: Initialize ==="
  terraform -chdir="${root_dir}" init

  echo
  echo "=== ${root_name}: Validate ==="
  terraform -chdir="${root_dir}" validate

  echo
  echo "=== ${root_name}: Current Terraform state ==="
  terraform -chdir="${root_dir}" state list | sort || true

  echo
  echo "=== ${root_name}: ${action^} Plan ==="

  if [[ "${action}" == "create" ]]; then
    terraform -chdir="${root_dir}" plan \
      -var-file="../terraform.tfvars" \
      -out="${plan_file}"
  else
    terraform -chdir="${root_dir}" plan \
      -destroy \
      -var-file="../terraform.tfvars" \
      -out="${plan_file}"
  fi

  echo
  read -r -p "${action^} ${root_name}? Type yes to continue: " confirmation

  if [[ "${confirmation}" != "yes" ]]; then
    rm -f "${root_dir}/${plan_file}"
    echo "${action^} cancelled for ${root_name}."
    exit 0
  fi

  echo
  echo "=== ${root_name}: ${action^} ==="
  terraform -chdir="${root_dir}" apply "${plan_file}"

  rm -f "${root_dir}/${plan_file}"
}

echo "Terraform operation:"
echo "  create  - Apply infrastructure and OpenWrt configuration"
echo "  destroy - Destroy OpenWrt configuration first, then infrastructure"
echo
read -r -p "Choose create or destroy: " operation

case "${operation}" in
  create|destroy)
    ;;
  *)
    echo "ERROR: Invalid operation: ${operation}. Choose create or destroy." >&2
    exit 1
    ;;
esac

if [[ "${operation}" == "create" ]]; then
  run_terraform_root "wrt-evpn" "${infra_dir}" "create"
  run_terraform_root "network" "${config_dir}" "create"

  clear_k8s_known_hosts
else
  run_terraform_root "network" "${config_dir}" "destroy"
  run_terraform_root "wrt-evpn" "${infra_dir}" "destroy"
fi
