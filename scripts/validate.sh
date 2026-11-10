#!/usr/bin/env bash
# Validate all configurations
# Usage: ./scripts/validate.sh

set -euo pipefail

echo "=============================================="
echo "  Validating EKS GitOps Platform"
echo "=============================================="
echo ""

# Terraform
echo "=== Terraform ==="
cd terraform
terraform fmt -check
terraform init -backend=false
terraform validate
cd ..

# Helm
echo "=== Helm ==="
helm lint helm/blueprint-app

# Kustomize
echo "=== Kustomize ==="
kustomize build gitops/apps/blueprint-app/overlays/dev
kustomize build gitops/apps/blueprint-app/overlays/staging
kustomize build gitops/apps/blueprint-app/overlays/production

# OPA
echo "=== OPA ==="
opa test security/opa/tests/ security/opa/policies/ -v

# YAML lint
echo "=== YAML Lint ==="
yamllint -c .yamllint .

# Python
echo "=== Python ==="
cd app
ruff check src/
mypy src/ --ignore-missing-imports
python -m pytest
cd ..

# Dockerfile
echo "=== Dockerfile ==="
hadolint app/Dockerfile

echo ""
echo "=== All validations passed ==="
