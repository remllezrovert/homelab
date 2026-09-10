#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

if [[ ! -f .env ]]; then
  echo "ERROR: Missing ${script_dir}/.env" >&2
  exit 1
fi

set -a
source "${script_dir}/.env"
set +a


terraform fmt
terraform init
terraform validate

echo
echo '=== Current Terraform state ==='
terraform state list | sort || true

echo
echo '=== Plan ==='
terraform plan

echo
read -r -p 'Apply this plan? Type yes to continue: ' confirmation

if [[ "$confirmation" != "yes" ]]; then
  echo 'Apply cancelled.'
  exit 0
fi

terraform apply
