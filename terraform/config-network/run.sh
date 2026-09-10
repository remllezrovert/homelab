#!/usr/bin/env bash

set -euo pipefail

set -a
source .env
set +a

terraform fmt
terraform init
terraform validate

echo

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
