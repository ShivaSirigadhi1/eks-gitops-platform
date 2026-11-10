# Setup Guide

## Prerequisites

1. **GitHub repository** created (public or private)
2. **AWS account** with permissions for EKS, VPC, ECR, IAM, KMS
3. **Container registry** access (default: ghcr.io, can use ECR)
4. **Argo CD** installed on your cluster (via Terraform)
5. **GitHub Actions** enabled on your repository
6. **Local tools**: Terraform, kubectl, helm, k3d (for local validation)

## Step 1: Configure GitHub Repository

### Secrets (Settings → Secrets and variables → Actions)

| Secret | Description |
|--------|-------------|
| `GITOPS_PAT` | GitHub Personal Access Token with repo scope for GitOps repo commits |
| `SLACK_WEBHOOK_URL` | Slack webhook for deployment notifications |
| `AWS_ROLE_ARN` | IAM role ARN for GitHub Actions OIDC (created by Terraform) |

### Environments (Settings → Environments)

Create these environments for deployment gates:
- `staging-approval` — Required reviewers: 1
- `production-approval` — Required reviewers: 2

## Step 2: Initialize Template Variables

Run the setup script to replace placeholder values:

```bash
./scripts/setup.sh
```

This will prompt for:
- Project name
- Container registry
- Argo CD server URL
- GitHub repo URL
- Kubernetes namespace prefix
- Cluster domain

## Step 3: Deploy Infrastructure (Terraform)

```bash
cd terraform

# Initialize
terraform init

# Plan (review changes)
terraform plan -var-file=environments/dev/terraform.tfvars

# Apply (requires valid AWS credentials)
terraform apply -var-file=environments/dev/terraform.tfvars
```

## Step 4: Bootstrap Argo CD

After Terraform creates the cluster:

```bash
# Install Argo CD (if not done by Terraform)
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply AppProjects and ApplicationSets
kubectl apply -f gitops/argocd/projects/
kubectl apply -f gitops/argocd/applicationsets/
```

## Step 5: Verify CI/CD Pipeline

1. Push first commit to `main`:
   ```bash
   git add .
   git commit -m "Initial commit: EKS GitOps Platform"
   git push origin main
   ```

2. Monitor CI pipeline: `https://github.com/your-org/eks-gitops-platform/actions`

3. Verify Argo CD syncs to Dev:
   ```bash
   argocd app list
   argocd app get blueprint-app-dev
   kubectl get pods -n blueprint-dev
   ```

## Step 6: Local Development (Optional)

```bash
# Bootstrap local k3d cluster
./scripts/bootstrap.sh

# Validate all configs
./scripts/validate.sh

# Deploy locally
./scripts/deploy-local.sh dev
```

## Template Variables Reference

| Variable | Default | Files |
|----------|---------|-------|
| `IMAGE_REGISTRY` | `ghcr.io/your-org` | `.github/workflows/*.yaml` |
| `IMAGE_NAME` | `blueprint-app` | `.github/workflows/*.yaml` |
| `ARGOCD_SERVER` | `argocd.example.com` | `.github/workflows/cd-*.yaml` |
| `namePrefix` | `blueprint-` | `k8s/base/kustomization.yaml` |
| `namespace` | `blueprint-system` | `k8s/base/kustomization.yaml` |
| `repoURL` | `https://github.com/your-org/eks-gitops-platform` | `gitops/argocd/apps/*.yaml` |
| `domain_name` | `example.com` | `terraform/environments/*/terraform.tfvars` |
