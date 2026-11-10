# EKS GitOps Platform — Enterprise Design Document

## Intent & Why

Build a production-grade, end-to-end Kubernetes application delivery platform on AWS EKS using GitOps principles. The platform provisions infrastructure via Terraform, builds and scans containers via GitHub Actions CI, stores images in Amazon ECR, and deploys via Argo CD with progressive delivery (canary/blue-green). This demonstrates enterprise DevOps capabilities: IaC, GitOps, SecOps, observability, multi-environment promotion, and disaster recovery.

**Target audience:** DevOps/platform engineers, SREs, and hiring managers evaluating senior DevOps skills.

## Goals

| Goal | Success Criteria |
|------|------------------|
| **Infrastructure as Code** | Terraform provisions VPC, EKS cluster, ECR repos, IAM roles (OIDC), and Argo CD in < 30 min |
| **GitOps Delivery** | Argo CD reconciles from Git; zero manual `kubectl apply` in production |
| **CI/CD Separation** | CI builds/tests/scans/pushes to ECR; CD is Argo CD pull-only (no cluster creds in CI) |
| **Multi-Environment** | Dev (auto), Staging (manual approval), Production (2-reviewer + canary + auto-rollback) |
| **Security by Default** | OPA/Gatekeeper policies, image signing, SBOM, Trivy scans, least-privilege RBAC, IRSA |
| **Observability** | Prometheus/Grafana/Loki/Tempo/OTel; alerting with runbooks |
| **Disaster Recovery** | Git is source of truth; rollback = Git revert; documented procedures |
| **Local Development** | k3d/kind cluster for validation without AWS costs |

## Non-Goals

- Multi-cluster management (single EKS cluster for demo)
- Service mesh (Istio/Linkerd) — optional future
- Database provisioning (RDS) — out of scope
- Custom domain/TLS automation — uses AWS LB controller with ACM
- Cost optimization (Karpenter) — optional future

## Anti-Goals (What Would Make This a Failure)

- Storing AWS credentials in GitHub secrets
- CI deploying directly to cluster (`kubectl apply` / `helm upgrade`)
- Missing resource limits/requests on any workload
- No image signature verification in production
- No automated rollback on failed canary
- Manual namespace/secret creation

## Constraints

| Constraint | Decision |
|------------|----------|
| **AWS Credentials** | Invalid in current env → Terraform `plan` only; no `apply` |
| **Local Cluster** | k3d available (`k3d-gitops-lab`) for K8s manifest validation |
| **Container Registry** | ECR (production design); GHCR fallback for local validation |
| **Argo CD Install** | Helm chart via Terraform `helm_release` (day 0/1) |
| **Secrets** | External Secrets Operator → AWS Secrets Manager (design); Sealed Secrets fallback for demo |
| **Image Tags** | Immutable SHA tags (`sha-<short>`); `latest` only for dev |
| **Branching** | Trunk-based: `main` only; feature branches via PR |

## Approaches Considered

| Approach | Trade-off | Decision |
|----------|-----------|----------|
| **Kustomize-only** | Simple, no templating | ❌ No Helm chart packaging; harder to version/distribute |
| **Helm-only (Argo CD Helm source)** | Native Helm, values per env | ✅ Selected: Argo CD reads Helm chart + values files from Git |
| **Kustomize overlays + Helm chart** | Best of both | ❌ Over-engineered for demo |
| **Argo CD CLI in CI** | Simple | ❌ CI touches cluster; anti-pattern |
| **GitOps repo (config repo)** | True GitOps separation | ✅ Selected: CI commits image tag to GitOps repo; Argo CD watches GitOps repo |
| **Single repo (app + config)** | Simpler | ❌ Blurs CI/CD boundary; harder to audit |
| **EKS Managed Argo CD** | Less ops | ❌ Less control; self-hosted shows deeper skills |
| **IRSA + OIDC for GitHub Actions** | Zero long-lived keys | ✅ Selected: `aws-actions/configure-aws-credentials@v4` with role assumption |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DEVELOPER                                        │
│         git push → GitHub (main)                                              │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        GITHUB ACTIONS CI                                      │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐           │
│  │ Lint/   │→ │ Build   │→ │ Trivy   │→ │ SBOM    │→ │ Push to │           │
│  │ Test    │  │ Docker  │  │ Scan    │  │ (Syft)  │  │ ECR     │           │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘  └────┬────┘           │
│                                                             │                │
│                              ┌──────────────────────────────┘                │
│                              ▼                                                   │
│                    ┌─────────────────┐                                         │
│                    │ Update GitOps   │                                         │
│                    │ Repo: values-   │                                         │
│                    │ <env>.yaml      │                                         │
│                    └────────┬────────┘                                         │
└─────────────────────────────┼─────────────────────────────────────────────────┘
                              │ Git commit (PR for prod)
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        GITOPS REPO (config)                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ values-dev   │  │ values-staging│ │ values-prod │  │ AppProjects, │     │
│  │ .yaml        │  │ .yaml        │  │ .yaml       │  │ Application- │     │
│  └──────────────┘  └──────────────┘  └──────────────┘  │ Sets          │     │
│                                                         └───────┬───────┘     │
└─────────────────────────────────────────────────────────────┼───────────────┘
                                                              │ Argo CD polls
                                                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ARGO CD (in EKS)                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Application  │  │ Application  │  │ Application  │  │ AppProject   │     │
│  │ Set (dev)    │  │ Set (staging)│  │ Set (prod)   │  │ (boundaries) │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────────────┘     │
│         │                 │                 │                                │
│         ▼                 ▼                 ▼                                │
│  ┌──────────────────────────────────────────────────────┐                    │
│  │              EKS CLUSTER (private)                    │                    │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────────┐ │                    │
│  │  │ blueprint│ │blueprint│ │blueprint│ │ monitoring  │ │                    │
│  │  │ -dev     │ │ -staging│ │ -prod   │ │ (Prom,      │ │                    │
│  │  └─────────┘ └─────────┘ └─────────┘ │ Grafana,    │ │                    │
│  │         ▲                 ▲           │ Loki,       │ │                    │
│  │         │                 │           │ Tempo, OTel)│ │                    │
│  │         │                 │           └─────────────┘ │                    │
│  │         │                 │           ┌─────────────┐ │                    │
│  │         │                 └──────────►│Argo Rollouts│ │                    │
│  │         │                             │(canary/     │ │                    │
│  │         │                             │blue-green)  │ │                    │
│  │         └────────────────────────────►│             │ │                    │
│  └──────────────────────────────────────────────────────┘                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Repository Structure (Monorepo with Clear Separation)

```
eks-gitops-platform/
├── .github/
│   ├── workflows/
│   │   ├── ci.yaml                 # Build, test, scan, push ECR
│   │   ├── cd-update-gitops.yaml   # Update GitOps repo values (dev/staging)
│   │   ├── cd-production.yaml      # Manual approval + canary deploy
│   │   ├── security-scan.yaml      # Weekly + PR security scans
│   │   └── dependabot.yaml         # Auto dependency updates
│   └── dependabot.yaml
├── terraform/                      # Infrastructure as Code (Day 0/1)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   ├── providers.tf
│   ├── backend.tf                  # S3 + DynamoDB locking
│   ├── modules/
│   │   ├── vpc/                    # VPC, subnets, NAT, endpoints
│   │   ├── eks/                    # EKS cluster, managed node groups
│   │   ├── ecr/                    # ECR repos, lifecycle, scan-on-push
│   │   ├── iam/                    # IRSA roles, OIDC provider, GitHub Actions role
│   │   ├── argocd/                 # Argo CD Helm release + bootstrap
│   │   ├── alb-controller/         # AWS Load Balancer Controller
│   │   ├── external-secrets/       # External Secrets Operator
│   │   └── monitoring/             # Prometheus, Grafana, Loki, Tempo (optional)
│   └── environments/
│       ├── dev/
│       ├── staging/
│       └── prod/
├── helm/
│   └── blueprint-app/              # Application Helm chart
│       ├── Chart.yaml
│       ├── values.yaml             # Defaults
│       ├── values-dev.yaml
│       ├── values-staging.yaml
│       ├── values-production.yaml
│       ├── templates/
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   ├── hpa.yaml
│       │   ├── ingress.yaml
│       │   ├── servicemonitor.yaml
│       │   ├── configmap.yaml
│       │   ├── secret.yaml         # Template (values from ExternalSecret)
│       │   ├── serviceaccount.yaml
│       │   ├── rollout.yaml        # Argo Rollout for canary
│       │   ├── analysis-template.yaml
│       │   ├── pdb.yaml
│       │   └── _helpers.tpl
│       └── charts/                 # Subcharts (if any)
├── gitops/                         # GitOps config repo (Day 2+)
│   ├── argocd/
│   │   ├── projects/
│   │   │   ├── platform.yaml       # Platform team: full access
│   │   │   └── workloads.yaml      # App teams: namespace-scoped
│   │   ├── applicationsets/
│   │   │   ├── apps-dev.yaml
│   │   │   ├── apps-staging.yaml
│   │   │   └── apps-production.yaml
│   │   └── argocd-cm.yaml          # Argo CD config (repositories, credentials)
│   ├── apps/
│   │   └── blueprint-app/
│   │       ├── base/               # HelmRelease or Kustomize base
│   │       ├── overlays/
│   │       │   ├── dev/
│   │       │   ├── staging/
│   │       │   └── production/
│   │       └── values/
│   │           ├── values-dev.yaml
│   │           ├── values-staging.yaml
│   │           └── values-production.yaml
│   └── clusters/
│       └── eks-prod/               # Cluster registration (if multi-cluster)
├── app/                            # Sample application (FastAPI + OTel)
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── pyproject.toml
│   ├── .env.example
│   ├── src/
│   │   ├── main.py
│   │   ├── routers/
│   │   ├── services/
│   │   ├── models/
│   │   └── telemetry/
│   └── tests/
├── security/
│   ├── opa/
│   │   ├── policies/
│   │   │   ├── deny_privileged.rego
│   │   │   ├── require_resources.rego
│   │   │   ├── require_image_source.rego
│   │   │   ├── require_labels.rego
│   │   │   └── require_signed_images.rego
│   │   └── tests/
│   ├── trivy/
│   │   ├── trivy-operator.yaml
│   │   └── scan-schedule.yaml
│   ├── cosign/
│   │   ├── cosign-keypair.yaml     # For demo (prod: KMS/HSM)
│   │   └── verify-policy.yaml
│   └── vault/
│       ├── vault-config.yaml
│       └── policies/
├── observability/
│   ├── prometheus/
│   │   ├── prometheus.yaml
│   │   ├── alerting-rules.yaml
│   │   └── servicemonitor.yaml
│   ├── grafana/
│   │   ├── dashboards/
│   │   │   ├── app-overview.json
│   │   │   ├── kubernetes-cluster.json
│   │   │   └── argocd.json
│   │   └── provisioning/
│   ├── loki/
│   │   └── loki-config.yaml
│   ├── tempo/
│   │   └── tempo-config.yaml
│   ├── opentelemetry/
│   │   └── otel-collector.yaml
│   └── alertmanager/
│       └── alertmanager.yaml
├── scripts/
│   ├── bootstrap.sh                # One-time setup (local k3d + Argo CD)
│   ├── validate.sh                 # Lint: helm, kustomize, opa, terraform
│   ├── deploy-local.sh             # Deploy to k3d for validation
│   └── rollback.sh                 # Git-based rollback helper
├── docs/
│   ├── ARCHITECTURE.md
│   ├── SETUP.md
│   ├── RUNBOOK.md
│   ├── SECURITY.md
│   ├── TROUBLESHOOTING.md
│   └── DESIGN.md                   # This file
├── Makefile
├── .gitignore
├── .gitleaks.toml
├── .pre-commit-config.yaml
└── README.md
```

## Key Dependencies

| Category | Dependency | Version | Purpose |
|----------|------------|---------|---------|
| **Infrastructure** | Terraform | >= 1.15 | AWS provisioning |
| | AWS Provider | >= 5.0 | EKS, VPC, ECR, IAM |
| | Helm Provider | >= 2.0 | Argo CD, add-ons |
| | Kubernetes Provider | >= 2.0 | K8s resources |
| **Cluster** | EKS | 1.31 | Kubernetes version |
| | Argo CD | v2.14+ | GitOps controller |
| | Argo Rollouts | v1.7+ | Progressive delivery |
| | AWS LB Controller | v2.7+ | ALB ingress |
| | External Secrets | v0.13+ | Secrets from AWS SM |
| | Gatekeeper | v3.18+ | OPA admission |
| | Cert Manager | v1.16+ | TLS certs |
| | Prometheus Operator | v0.77+ | Monitoring stack |
| **CI/CD** | GitHub Actions | - | Workflow engine |
| | docker/build-push-action | v6 | Multi-arch builds |
| | aws-actions/configure-aws-credentials | v4 | OIDC auth |
| | aws-actions/amazon-ecr-login | v2 | ECR auth |
| | anchore/sbom-action | v0.17+ | SBOM generation |
| | aquasecurity/trivy-action | v0.28+ | Vuln scanning |
| | gitleaks/gitleaks-action | v2 | Secrets scan |
| | github/codeql-action | v3 | SAST |
| **Application** | Python | 3.12 | Runtime |
| | FastAPI | 0.115 | Web framework |
| | Uvicorn | 0.30 | ASGI server |
| | OpenTelemetry | 1.27 | Tracing/metrics |
| | Prometheus Client | 0.20 | Metrics |
| | Structlog | 24.4 | Structured logging |
| **Validation** | kustomize | v5.8+ | K8s manifests |
| | helm | v4.1+ | Chart linting |
| | opa | v0.68+ | Policy testing |
| | trivy | v0.58+ | Image scanning |
| | cosign | v2.2+ | Image signing |
| | syft | v1.17+ | SBOM |

## Environment Promotion Model

```
┌──────────────┐    ┌──────────────┐    ┌──────────────────┐    ┌──────────────┐
│   COMMIT     │───►│     CI       │───►│   GITOPS REPO    │───►│   ARGO CD    │
│   (main)     │    │ (build/scan) │    │ (values-dev.yaml)│    │   (auto)     │
└──────────────┘    └──────────────┘    └──────────────────┘    └──────┬───────┘
                                                                       │
                                                                       ▼
                                                                ┌──────────────┐
                                                                │     DEV      │
                                                                │ (auto-sync)  │
                                                                └──────┬───────┘
                                                                       │
                                                                       ▼
                                                                ┌──────────────┐
                                                                │   STAGING    │
                                                                │ (manual PR   │
                                                                │  approval)   │
                                                                └──────┬───────┘
                                                                       │
                                                                       ▼
                                                                ┌──────────────┐
                                                                │  PRODUCTION  │
                                                                │ (2-reviewer  │
                                                                │  approval +  │
                                                                │  canary)     │
                                                                └──────────────┘
```

| Environment | Sync Policy | Approval | Canary | Auto-Rollback |
|-------------|-------------|----------|--------|---------------|
| Dev | Automated (prune, self-heal) | None | No | N/A |
| Staging | Automated (prune, self-heal) | Manual (GH env) | No | N/A |
| Production | Manual (Argo CD UI/CLI) | 2 reviewers (GH env) | Yes (10%→100%) | Yes (analysis fail) |

## Security Architecture

| Layer | Control |
|-------|---------|
| **Code** | Gitleaks (secrets), CodeQL (SAST), Dependabot (deps) |
| **Container** | Trivy (vuln), Syft (SBOM), Cosign (sign), Gatekeeper (admission) |
| **Runtime** | Trivy Operator (continuous scan), OPA (resource limits, privileged, labels) |
| **Network** | Private EKS endpoint, ALB with WAF, NetworkPolicy default-deny |
| **Identity** | IRSA for pods, OIDC for GitHub Actions, AWS SSO for Argo CD |
| **Secrets** | External Secrets → AWS Secrets Manager; no secrets in Git |
| **Supply Chain** | SLSA Level 2: signed images, SBOM, provenance, reproducible builds |

## Argo CD ApplicationSet Design

```yaml
# Matrix generator: services × environments
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: blueprint-app
  namespace: argocd
spec:
  generators:
  - matrix:
      generators:
      - git:
          repoURL: https://github.com/org/eks-gitops-platform
          revision: main
          directories:
          - path: gitops/apps/blueprint-app/values/*
      - clusters:
          selector:
            matchLabels:
              environment: "{{path.basename}}"
  template:
    metadata:
      name: "blueprint-app-{{path.basename}}"
    spec:
      project: workloads
      source:
        repoURL: https://github.com/org/eks-gitops-platform
        targetRevision: main
        chart: helm/blueprint-app
        helm:
          valueFiles:
          - "$values/values-{{path.basename}}.yaml"
      destination:
        server: "{{server}}"
        namespace: "blueprint-{{path.basename}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
        retry:
          limit: 5
          backoff:
            duration: 5s
            factor: 2
            maxDuration: 3m
```

## Canary Analysis (Argo Rollouts)

```yaml
# analysis-template.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: canary-analysis
spec:
  args:
  - name: service-name
  - name: namespace
  metrics:
  - name: error-rate
    interval: 30s
    count: 5
    successCondition: result[0] <= 0.01
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc:9090
        query: |
          sum(rate(http_requests_total{service="{{args.service-name}}",namespace="{{args.namespace}}",status=~"5.."}[2m]))
          /
          sum(rate(http_requests_total{service="{{args.service-name}}",namespace="{{args.namespace}"}[2m]))
  - name: latency-p99
    interval: 30s
    count: 5
    successCondition: result[0] <= 2.0
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc:9090
        query: |
          histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{service="{{args.service-name}}",namespace="{{args.namespace}}"}[2m])) by (le))
```

## Validation Checklist (Pre-Commit + CI)

| Check | Tool | When |
|-------|------|------|
| Terraform fmt/validate | `terraform fmt -check`, `terraform validate` | Pre-commit, CI |
| Terraform plan | `terraform plan` | CI (no apply without creds) |
| Helm lint | `helm lint helm/blueprint-app` | Pre-commit, CI |
| Helm template render | `helm template` | CI |
| Kustomize build | `kustomize build` | CI |
| OPA policy test | `opa test` | Pre-commit, CI |
| OPA policy check (admission) | `opa eval` | CI |
| Dockerfile lint | `hadolint` | CI |
| Python lint/test | `ruff`, `mypy`, `pytest` | Pre-commit, CI |
| YAML lint | `yamllint` | Pre-commit, CI |
| Secrets scan | `gitleaks` | Pre-commit, CI |
| Dependency review | `dependabot` | Weekly + PR |

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| AWS creds invalid → cannot `terraform apply` | High | High | Design for `plan` only; validate locally with k3d |
| Argo CD install fails | Medium | High | Pin Helm chart version; test on k3d first |
| ECR image push fails (perms) | Medium | High | OIDC role with least-privilege ECR policy |
| Canary analysis false positive | Medium | Medium | Tunable thresholds; manual override |
| External Secrets Operator not ready | Low | High | Sealed Secrets fallback for demo |
| Cost overrun (EKS managed nodes) | Medium | Medium | Spot instances for dev; stop after demo |

## Approval Gate

**HARD-GATE:** Nothing gets built until this design doc is approved. Building includes writing code, scaffolding, installing dependencies, creating projects.

---

*Generated: 2026-11-10*  
*Author: Hermes Agent (Ponytail Full Mode)*  
*Next Step: Review this design. If approved, I'll create the implementation plan (superpowers:writing-plans) and begin building.*