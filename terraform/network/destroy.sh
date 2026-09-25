#!/usr/bin/env bash

set -euo pipefail

set -a
source .env
set +a

terraform fmt
terraform init
terraform validate

echo
echo '=== Destroy plan ==='
terraform plan -destroy

echo
read -r -p 'Destroy all Terraform-managed resources? Type destroy to continue: ' confirmation

if [[ "$confirmation" != "destroy" ]]; then
  echo 'Destroy cancelled.'
  exit 0
fi

terraform destroy
