# EKS GitOps Platform

> **Production-grade Kubernetes application delivery platform on AWS EKS using GitOps principles**

[![CI](https://github.com/your-org/eks-gitops-platform/actions/workflows/ci.yaml/badge.svg)](https://github.com/your-org/eks-gitops-platform/actions/workflows/ci.yaml)
[![Security](https://github.com/your-org/eks-gitops-platform/actions/workflows/security-scan.yaml/badge.svg)](https://github.com/your-org/eks-gitops-platform/actions/workflows/security-scan.yaml)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Overview

This platform demonstrates enterprise DevOps capabilities by automating the complete application delivery lifecycle:

```
┌─────────────┐     ┌─────────────┐     ┌────────────┐     ┌──────────────┐
│ Developer   │     │ GitHub      │     │ AWS ECR    │     │ AWS EKS      │
│             │────►│ Actions CI  │────►│ Container  │────►│ Cluster      │
│             │     │             │     │ Registry   │     │              │
└─────────────┘     └─────┬───────┘     └────┬───────┘     └─────┬────────┘
          Git Change       │                    │                   │
                           ▼                    ▼                   ▼
                 ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
                 │ GitHub Actions  │   │ Argo CD (GitOps)│   │ Application     │
                 │ Updates Values  │   │ Reconciles      │   │ Running         │
                 │ File in GitOps  │   │ from Git        │   │ Workload        │
                 └────────┬────────┘   └───────┬─────────┘   └─────────────────┘
                          │                    │
                          ▼                    ▼
                 ┌────────────────────────────────────────────────────┐
                 │        GITOPS CONFIG REPOSITORY                    │
                 │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
                 │  │ values-dev  │  │ values-stg  │  │ values-prod │  │
                 │  │ .yaml       │  │ .yaml       │  │ .yaml       │  │
                 │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  │
                 │         │                │                │         │
                 │         └──────┬─────────┴──────┬─────────┘         │
                 │                │                │                 │
                 │        ┌─────────▼────────┐     │                 │
                 │        │ ApplicationSet   │     │                 │
                 │        │ (Matrix)         │─────┘                 │
                 │        └──────────────────┘                       │
                 └────────────────────────────────────────────────────┘
```

## Key Features

| Category | Features |
|----------|----------|
| **Infrastructure as Code** | Terraform provisions VPC, EKS, ECR, IAM, Argo CD, ALB Controller, External Secrets |
| **GitOps Delivery** | Argo CD continuously reconciles from Git; zero manual `kubectl apply` in production |
| **CI/CD Separation** | CI builds/tests/scans/pushes to ECR; CD is Argo CD pull-only (no cluster creds in CI) |
| **Multi-Environment** | Dev (auto), Staging (manual approval), Production (2-reviewer + canary + auto-rollback) |
| **Security by Default** | OIDC, IRSA, OPA policies, image signing, SBOM, Trivy scans, least-privilege RBAC |
| **Observability** | Prometheus/Grafana/Loki/Tempo/OTel; alerting with runbooks |
| **Disaster Recovery** | Git is source of truth; rollback = Git revert; documented procedures |

## Quick Start

### Prerequisites
- AWS account with appropriate permissions
- GitHub repository
- Local tools: `terraform`, `kubectl`, `helm`, `k3d` (for local validation)

### 1. Configure Repository
```bash
# Clone and configure
git clone https://github.com/your-org/eks-gitops-platform.git
cd eks-gitops-platform
./scripts/setup.sh
```

### 2. Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

### 3. Bootstrap GitOps
```bash
# Apply Argo CD projects and ApplicationSets
kubectl apply -f gitops/argocd/projects/
kubectl apply -f gitops/argocd/applicationsets/
```

### 4. Trigger First Deployment
```bash
git add .
git commit -m "Initial commit"
git push origin main
```

Monitor at: `https://github.com/your-org/eks-gitops-platform/actions`

### 5. Local Development (Optional)
```bash
./scripts/bootstrap.sh     # Creates k3d cluster + Argo CD
./scripts/validate.sh      # Runs all lint/validation checks
./scripts/deploy-local.sh dev  # Deploys to local cluster
```

## Repository Structure

```
eks-gitops-platform/
├── .github/
│   ├── workflows/           # CI, CD (dev/staging auto, prod canary), security
│   └── dependabot.yaml      # Auto dependency updates
├── terraform/               # Infrastructure as Code
│   ├── modules/             # VPC, EKS, ECR, IAM, Argo CD, ALB, External Secrets
│   └── environments/        # Dev, Staging, Prod tfvars
├── helm/
│   └── blueprint-app/       # Application Helm chart with Argo Rollout
├── gitops/                  # GitOps config (Argo CD AppProjects, ApplicationSets)
│   ├── argocd/
│   └── apps/blueprint-app/
├── app/                     # Sample FastAPI application
│   ├── src/                 # Routers, services, models, telemetry
│   └── tests/
├── security/                # OPA policies, Trivy, Cosign, Vault
├── observability/           # Prometheus, Grafana, Loki, Tempo, OTel, Alertmanager
├── scripts/                 # bootstrap, validate, deploy-local, rollback
└── docs/                    # SETUP, RUNBOOK, ARCHITECTURE, SECURITY, TROUBLESHOOTING
```

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | Step-by-step deployment guide |
| [RUNBOOK.md](docs/RUNBOOK.md) | Operational procedures (rollback, debugging, alerts) |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System architecture diagrams and component relationships |
| [SECURITY.md](docs/SECURITY.md) | Security architecture, policies, compliance |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues and solutions |
| [knowledge.md](docs/knowledge.md) | Complete project knowledge base + interview prep |

## Technology Stack

| Layer | Technologies |
|-------|--------------|
| **Infrastructure** | Terraform, AWS (EKS, VPC, ECR, IAM, KMS, ALB) |
| **GitOps** | Argo CD, Argo Rollouts, Helm, Kustomize |
| **CI/CD** | GitHub Actions, Docker Buildx, Trivy, Syft, Cosign, CodeQL |
| **Kubernetes** | EKS 1.31, OPA/Gatekeeper, External Secrets, Cert Manager |
| **Application** | Python 3.12, FastAPI, OpenTelemetry, Prometheus Client |
| **Observability** | Prometheus, Grafana, Loki, Tempo, Alertmanager, OTel |

## Security Highlights

- **Zero long-lived credentials**: OIDC for GitHub Actions → AWS, IRSA for pods
- **Supply chain security**: Trivy scans, Syft SBOM, Cosign signatures
- **Admission control**: OPA/Gatekeeper policies (privileged, resources, labels, image source, signatures)
- **Secrets management**: External Secrets Operator → AWS Secrets Manager
- **Network isolation**: Private EKS endpoint, ALB with WAF, NetworkPolicy default-deny

## Contributing

1. Fork the repository
2. Create a feature branch
3. Run `./scripts/validate.sh` before committing
4. Submit a PR with description of changes
5. CI must pass + code review approval

## License

MIT License - see [LICENSE](LICENSE)

## Interview Preparation

This project includes comprehensive interview preparation material in [docs/knowledge.md](docs/knowledge.md):

- 15 real-time interview questions with expert answers
- Architecture deep-dive talking points
- Troubleshooting scenarios
- Tips & strategies for senior DevOps interviews
