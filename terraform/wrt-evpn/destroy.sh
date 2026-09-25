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
echo '=== Destroy plan ==='
terraform plan -destroy

echo
echo 'WARNING: This will destroy every resource managed by this Terraform state.'
read -r -p 'Destroy this infrastructure? Type yes to continue: ' confirmation

if [[ "$confirmation" != "yes" ]]; then
  echo 'Destroy cancelled.'
  exit 0
fi

terraform destroy
