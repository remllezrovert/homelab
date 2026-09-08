#!/bin/bash

set -e
set -a
source .env
set +a

terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
