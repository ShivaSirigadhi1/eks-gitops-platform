# Knowledge Base: EKS GitOps Platform — Enterprise Deployment Mastery

## Table of Contents

1. [Project Overview](#project-overview)
2. [Step-by-Step Build Guide](#step-by-step-build-guide)
3. [Why Each Technology Choice](#why-each-technology-choice)
4. [Problems Being Solved](#problems-being-solved)
5. [Interview Preparation](#interview-preparation)
6. [Real-time Interview Questions](#real-time-interview-questions)
7. [Tips, Tricks & Strategies](#tips-tricks-and-strategies)

---

## Project Overview

### What Is This?
The **EKS GitOps Platform** is an end-to-end, production-grade Kubernetes application delivery platform built on **AWS EKS** using **GitOps principles**. It demonstrates enterprise DevOps skills by automating infrastructure provisioning, container builds, security scanning, and progressive delivery.

### Core Architecture & Flow
1. **Developer pushes code** to `main` branch.
2. **GitHub Actions CI** triggers: lints, runs pytest, builds multi-arch Docker image with Buildx, scans with Trivy, generates SBOM with Syft, signs with Cosign, pushes immutable SHA tag to **Amazon ECR**.
3. **CI updates GitOps repo**: GitHub Actions automatically updates `gitops/apps/blueprint-app/values/values-dev.yaml` (or staging/prod) with the new image SHA tag and commits back.
4. **Argo CD reconciles**: Argo CD constantly watches the GitOps repo. When it detects a new SHA tag, it marks the Application `OutOfSync` and deploys the change to **AWS EKS** (Dev/Staging automatically, Production via gated PR/manual sync).
5. **Progressive Delivery**: Production deployments use **Argo Rollouts** for canary deployments (10% → 30% → 50% → 100%) with Prometheus-backed analysis (error rate <= 1%, p99 latency <= 2s) and automatic rollback on failure.

---

## Step-by-Step Build Guide

### Step 1: Repository Scaffold & Tooling
- **Files**: `.gitignore`, `.gitleaks.toml`, `.pre-commit-config.yaml`, `Makefile`, `README.md`, `docs/`.
- **Why**: Pre-commit hooks catch syntax errors, lint issues, and exposed secrets before code ever reaches GitHub. Gitleaks scans git history. Makefile standardizes development tasks (`make validate`, `make lint`, `make docker-build`).

### Step 2: Application Code (FastAPI + OTel)
- **Files**: `app/Dockerfile`, `app/requirements.txt`, `app/src/main.py`, `app/src/routers/`, `app/src/services/`, `app/src/telemetry/`, `app/tests/`.
- **Why**: FastAPI provides high-performance asynchronous HTTP endpoints. OpenTelemetry (OTel) provides vendor-neutral distributed tracing exported via OTLP to Tempo/Jaeger. Structlog outputs JSON logs parsed by Loki. Prometheus instrumentator exposes `/metrics` for Prometheus scraping.

### Step 3: Helm Chart Packaging
- **Files**: `helm/blueprint-app/Chart.yaml`, `values.yaml`, `values-dev.yaml`, `values-staging.yaml`, `values-production.yaml`, `templates/`.
- **Why**: Helm packages Kubernetes manifests into reusable, parameterizable templates. Environment-specific values files (`values-dev.yaml`, `values-production.yaml`) allow Argo CD to render environment-specific deployments without duplicating manifest files.

### Step 4: Terraform Infrastructure (Day 0/1)
- **Files**: `terraform/main.tf`, `modules/vpc/`, `modules/eks/`, `modules/ecr/`, `modules/iam/`, `modules/argocd/`, `modules/alb-controller/`, `modules/external-secrets/`, `environments/`.
- **Why**: Terraform provisions AWS infrastructure declaratively. VPC module sets up public/private subnets across 3 AZs with NAT gateways and VPC endpoints. EKS module provisions a private-endpoint cluster with managed node groups and IRSA. IAM module sets up OIDC for GitHub Actions (keyless AWS auth) and IRSA roles for cluster add-ons.

### Step 5: GitOps Configuration (Day 2+)
- **Files**: `gitops/argocd/projects/`, `gitops/argocd/applicationsets/`, `gitops/apps/blueprint-app/`.
- **Why**: Separation of application source code from configuration (GitOps repo pattern). Argo CD AppProjects enforce boundary rules (e.g., workloads cannot touch cluster-scoped resources). ApplicationSets use matrix generators to automatically generate Applications per service and environment.

### Step 6: GitHub Actions CI/CD Workflows
- **Files**: `.github/workflows/ci.yaml`, `cd-update-gitops.yaml`, `cd-production.yaml`, `security-scan.yaml`.
- **Why**: GitHub Actions separates CI (build, test, scan, push to ECR, update GitOps repo) from CD (Argo CD pulls from Git). Production CD requires 2-reviewer approval and canary deployment.

### Step 7: Security Policies (OPA, Trivy, Cosign, Vault)
- **Files**: `security/opa/policies/`, `security/trivy/`, `security/cosign/`, `security/vault/`.
- **Why**: OPA/Gatekeeper admission control blocks unapproved registries, missing resource limits, and privileged containers. Trivy Operator scans running pods. Cosign verifies image signatures.

### Step 8: Observability Stack
- **Files**: `observability/prometheus/`, `grafana/`, `loki/`, `tempo/`, `opentelemetry/`, `alertmanager/`.
- **Why**: Complete 3-pillar observability (Metrics via Prometheus, Logs via Loki, Traces via Tempo) visualized in Grafana dashboards, with Alertmanager routing alerts to Slack.

---

## Why Each Technology Choice

| Technology | Why Chosen | Alternative Considered | Why Alternative Rejected |
|------------|------------|------------------------|--------------------------|
| **AWS EKS** | Managed Kubernetes, robust AWS integration (IAM, VPC, ALB, ECR) | Self-managed K8s on EC2 | Too much operational overhead (upgrades, etcd backups) |
| **Argo CD** | Industry-standard declarative GitOps engine, powerful UI, self-healing | Flux CD | Argo CD has a richer UI and wider enterprise adoption |
| **GitHub Actions** | Built into GitHub, native OIDC AWS auth, huge marketplace | GitLab CI, Jenkins | Code is on GitHub; Jenkins requires maintaining controller infrastructure |
| **Helm** | Native Kubernetes package manager, values files per environment | Kustomize-only | Helm handles complex templating and versioning better across environments |
| **Terraform** | Declarative IaC, huge ecosystem, state locking (S3 + DynamoDB) | AWS CloudFormation | Terraform is cloud-agnostic and has cleaner syntax (HCL) |
| **FastAPI** | High-performance Python async framework, automatic OpenAPI docs | Flask, Django | Flask is synchronous; Django is too heavy for microservices |
| **OpenTelemetry** | Vendor-neutral tracing standard, supported by all APM tools | Datadog/NewRelic SDK | Vendor lock-in; OTel allows sending to Prometheus, Tempo, or any backend |
| **OPA / Gatekeeper** | Declarative admission control policies in Rego | Kyverno | OPA is the CNCF standard with mature policy testing frameworks |

---

## Problems Being Solved

1. **Drift Between Git and Cluster**: In traditional CI models (`kubectl apply` from Jenkins), live cluster state drifts due to manual hotfixes. **Solution**: Argo CD continuous reconciliation and self-healing immediately reverts unauthorized changes.
2. **Credentials Leak in CI/CD**: Storing long-lived AWS IAM keys in GitHub Secrets is a major security risk. **Solution**: OIDC keyless authentication allows GitHub Actions to assume an IAM role securely via temporary session tokens.
3. **CI Pipeline Touching Production**: Giving CI write access to production clusters means a compromised CI pipeline gives attackers cluster-admin access. **Solution**: CI only pushes to ECR and commits to a GitOps repo. Argo CD pulls from inside the cluster. CI has zero network path to EKS API.
4. **Zero-Downtime Releases & Bad Deploys**: Standard rolling updates can cause errors if a bad build reaches production. **Solution**: Argo Rollouts canary deployment shifts traffic incrementally while monitoring Prometheus error rate and latency, automatically rolling back if thresholds are breached.
5. **Lack of Resource Governance**: Teams deploying workloads without resource limits can starve other tenants and crash nodes. **Solution**: OPA/Gatekeeper admission controller enforces CPU/memory requests and limits on every pod.

---

## Interview Preparation & Q&A

### Top 15 Real-time Interview Questions & Answers

#### Q1: Walk me through your EKS GitOps platform architecture. How does code flow from a developer's commit to running in production?
* **Answer Structure**:
  1. **Source & CI**: Developer pushes code to `main`. GitHub Actions runs linting, pytest, builds multi-arch Docker image with Buildx, scans with Trivy, generates SBOM, signs with Cosign, and pushes the immutable image (tagged with commit SHA) to Amazon ECR.
  2. **GitOps Handoff**: CI commits the new image SHA tag into the GitOps config repository (`values-production.yaml`).
  3. **CD Reconciliation**: Argo CD, running inside the EKS cluster, polls the GitOps repo (or receives a webhook). It detects the `OutOfSync` state and synchronizes the cluster.
  4. **Progressive Delivery**: In production, Argo Rollouts deploys a canary (10%), evaluates Prometheus metrics (error rate, p99 latency), and if healthy, automatically promotes to 100%. If unhealthy, it auto-rollbacks.

#### Q2: Why did you separate the application repository from the GitOps configuration repository?
* **Answer**: Separation of concerns and security boundaries. 
  - **Auditability**: All infrastructure and deployment changes are tracked in the GitOps repo with pull request reviews.
  - **Security**: The CI pipeline for the application only needs ECR push permissions and Git commit permissions to the GitOps repo. It has **no network path or credentials** to the EKS cluster API. If the app CI is compromised, the attacker cannot access the cluster.

#### Q3: How do you handle secrets management securely in Kubernetes?
* **Answer**: We never store plaintext secrets in Git. 
  - Secrets are stored securely in **AWS Secrets Manager**.
  - The **External Secrets Operator** (ESO) runs in EKS and synchronizes secrets from AWS Secrets Manager into native Kubernetes Secrets using IAM Roles for Service Accounts (IRSA).
  - For GitOps, we only commit secret references/metadata (SecretStore and ExternalSecret CRDs), never the secret values themselves.

#### Q4: How does Argo CD handle self-healing and drift correction?
* **Answer**: Argo CD continuously compares the desired state in Git against the live cluster state. 
  - When `selfHeal: true` is enabled, if someone manually patches a resource on the cluster using `kubectl edit` or `kubectl scale`, Argo CD instantly detects the drift (`OutOfSync`), raises an alert, and automatically overwrites the change to match Git within minutes. In production, this ensures Git remains the single source of truth.

#### Q5: Explain how OIDC works with GitHub Actions for AWS authentication without storing static credentials.
* **Answer**: Instead of storing long-lived `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as GitHub repository secrets:
  - We configure an IAM OIDC Identity Provider in AWS trusting GitHub's OIDC issuer (`token.actions.githubusercontent.com`).
  - In GitHub Actions, the `aws-actions/configure-aws-credentials@v4` action requests a JSON Web Token (JWT) from GitHub's OIDC provider.
  - AWS IAM validates the JWT against the trust policy and issues short-lived, temporary AWS STS credentials for that specific workflow run.

#### Q6: How do you perform zero-downtime deployments and handle canary rollbacks?
* **Answer**: We use **Argo Rollouts** instead of standard Kubernetes Deployments for critical workloads.
  - Argo Rollouts creates a canary ReplicaSet alongside the stable ReplicaSet.
  - It shifts traffic in steps (e.g., 10% → 30% → 50% → 100%).
  - During each step, an `AnalysisTemplate` queries Prometheus every 30 seconds for HTTP 5xx error rates and p99 latency.
  - If error rate exceeds 1% or p99 latency exceeds 2 seconds, Argo Rollouts automatically aborts the rollout, shifts 100% traffic back to the stable ReplicaSet, and triggers an automated Git revert.

#### Q7: What are Kubernetes Probes, and how are they configured in your platform?
* **Answer**: Probes ensure application reliability and availability:
  - **Liveness Probe (`/healthz`)**: Checks if the container is running. If it fails repeatedly, Kubernetes kills and restarts the pod.
  - **Readiness Probe (`/readyz`)**: Checks if the app is ready to accept traffic (e.g., database connections established). If it fails, endpoints are removed from Service load balancing.
  - **Startup Probe**: Protects slow-starting containers by delaying liveness/readiness checks until startup completes.

#### Q8: How do you enforce compliance and security guardrails across Kubernetes clusters?
* **Answer**: We use **OPA (Open Policy Agente) with Gatekeeper** as an admission controller.
  - Rego policies run on every Kubernetes API request (`ValidatingWebhook`).
  - Policies enforce:
    - No container may run as root (`runAsNonRoot: true`).
    - All containers must define CPU and memory requests and limits.
    - Images must come from approved ECR registries (`ghcr.io/your-org/` or `123456789.dkr.ecr...`).
    - Production workloads cannot use the `:latest` tag.

#### Q9: How is observability structured in your platform?
* **Answer**: We implement the **3 Pillars of Observability**:
  - **Metrics**: FastAPI exposes `/metrics` via Prometheus client. Prometheus scrapes targets; Grafana visualizes RED metrics (Rate, Errors, Duration).
  - **Logs**: Structlog outputs structured JSON logs. OpenTelemetry filelog collector ships logs to **Loki**.
  - **Traces**: FastAPI and HTTP requests are instrumented with OpenTelemetry SDK, exporting OTLP traces to **Tempo** (and Jaeger UI).

#### Q10: How would you troubleshoot a crashing pod in production?
* **Answer**: A systematic approach:
  1. Check pod status: `kubectl get pods -n <namespace>`. If `CrashLoopBackOff`, check restart count.
  2. Inspect pod details: `kubectl describe pod <pod-name> -n <namespace>` (check exit code, OOMKilled, failed volume mounts, probe failures).
  3. View container logs: `kubectl logs <pod-name> -n <namespace> --previous` (check stack traces or missing environment variables).
  4. Check resource limits: ensure memory limit isn't too low causing OOMKilled.

#### Q11: How do you manage multi-environment configuration (Dev, Staging, Production)?
* **Answer**: We use Helm charts with environment-specific values files (`values-dev.yaml`, `values-staging.yaml`, `values-production.yaml`). 
  - Dev syncs automatically on every commit to `main`.
  - Staging syncs after manual approval in GitHub Actions.
  - Production requires 2-reviewer PR approval in the GitOps repo and manual sync approval in Argo CD.

#### Q12: What is the difference between Kustomize and Helm, and why did you choose Helm?
* **Answer**: 
  - **Kustomize** uses overlay patching on pure YAML manifests (no templating logic).
  - **Helm** uses chart templating (Go templates) with values parameters.
  - **Why Helm**: For enterprise platforms with multiple microservices and complex parameterization across environments, Helm charts provide better packaging, versioning, publishing to OCI registries, and values-driven overrides.

#### Q13: How do you handle disaster recovery for the GitOps control plane?
* **Answer**: 
  - Since **Git is the single source of truth** for all desired state (Helm charts, GitOps configs, Kubernetes manifests), losing the Argo CD cluster does not lose application state.
  - To recover: spin up a new EKS cluster, run Terraform to install Argo CD and connect it to the Git repository. Argo CD automatically re-syncs and restores all applications to their exact desired state.
  - Argo CD cluster configuration and application CRDs are backed up regularly via automated scripts.

#### Q14: How do you ensure high availability and fault tolerance for the application in EKS?
* **Answer**:
  - **Multi-AZ Deployment**: EKS nodes and pods are spread across 3 Availability Zones using `topologySpreadConstraints` and `podAntiAffinity`.
  - **Horizontal Pod Autoscaler (HPA)**: Automatically scales pods based on CPU (70%) and memory (80%) utilization.
  - **Pod Disruption Budget (PDB)**: Ensures a minimum number of pods (`minAvailable: 2`) are always running during node upgrades or disruptions.

#### Q15: How do you explain this project confidently in an interview?
* **Tip**: Frame it around business value and technical challenges: *"I built this platform to solve the classic bottleneck where CI pipelines write directly to production, risking un-audited changes and credential leaks. By separating CI (building immutable artifacts) from CD (Argo CD GitOps reconciliation) and adding OPA policy gates, automated canary rollouts with Prometheus analysis, and OIDC keyless AWS auth, we achieved a secure, self-healing, enterprise-grade GitOps delivery pipeline."*

---

## Interview Tips, Tricks & Strategies

1. **Lead with the 'Why'**: Interviewers care less about syntax and more about architectural tradeoffs. Always explain *why* you chose GitOps over push-based CI deployment, or OIDC over static AWS keys.
2. **Draw the Architecture on the Fly**: Be ready to sketch the flow: Developer → GitHub Actions CI → ECR → GitOps Repo → Argo CD → EKS.
3. **Master Troubleshooting Scenarios**: Prepare 2-3 real-world failure stories (e.g., "A bad config was pushed, Argo CD self-healed back to stable, or an OOMKilled pod triggered an HPA scale-up").
4. **Emphasize Security**: Mention OPA, IRSA, OIDC, and secrets management early. Security is top-of-mind for engineering leaders.
5. **Know Your Metrics**: Be ready to discuss RED metrics (Rate, Errors, Duration) and Kubernetes resource utilization (CPU/Memory requests vs limits).
