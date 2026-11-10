# EKS GitOps Platform — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a production-grade, end-to-end EKS GitOps platform with Terraform infrastructure, Helm application chart, Argo CD GitOps, GitHub Actions CI/CD, security, and observability.

**Architecture:** Monorepo with three logical layers — Terraform (infra), Helm (app packaging), GitOps (Argo CD config). CI builds/scans/pushes to ECR and updates GitOps values; Argo CD reconciles from Git.

**Tech Stack:** Terraform 1.15+, AWS Provider 5+, EKS 1.31, Helm 4.1+, Argo CD 2.14+, Argo Rollouts 1.7+, GitHub Actions, Python 3.12/FastAPI, Prometheus/Grafana/Loki/Tempo.

**Spec:** `/Users/shiva/Projects/eks-gitops-platform/docs/DESIGN.md`

## Global Constraints

- **AWS credentials invalid** — Terraform `plan` only; no `apply`. Validate manifests against local k3d cluster (`k3d-gitops-lab`).
- **Container registry** — ECR for production design; GHCR fallback for local validation (use `GITHUB_TOKEN`).
- **Argo CD install** — Helm release via Terraform `helm_release` (day 0/1).
- **Secrets** — External Secrets Operator → AWS Secrets Manager (design); Sealed Secrets fallback for demo.
- **Image tags** — Immutable SHA tags (`sha-<short>`); `latest` only for dev.
- **Branching** — Trunk-based: `main` only; feature branches via PR.
- **Validation** — All YAML/Helm/Terraform/OPA must lint and render cleanly in CI.

## Review Focus

1. **Missing resource limits/requests** — Every container must have CPU/memory requests and limits; OPA policy enforces this.
2. **Unsigned images in production** — Cosign verification required at admission; test with unsigned image to confirm rejection.
3. **Argo CD sync policy misconfiguration** — Production must be manual sync; verify `automated: null` or `automated.prune: false`.
4. **Secrets in Git** — No plaintext secrets anywhere; ExternalSecret/SealedSecret only.
5. **Canary analysis gaps** — AnalysisTemplate must cover error rate AND latency; empty results = failure.

---

## Task 1: Repository Scaffold & Tooling Config

**Files:**
- Create: `.gitignore`
- Create: `.gitleaks.toml`
- Create: `.pre-commit-config.yaml`
- Create: `Makefile`
- Create: `README.md`
- Create: `docs/SETUP.md`
- Create: `docs/RUNBOOK.md`
- Create: `docs/ARCHITECTURE.md`
- Create: `docs/SECURITY.md`
- Create: `docs/TROUBLESHOOTING.md`

**Interfaces:**
- Produces: Base repo structure, pre-commit hooks, developer documentation

- [ ] **Step 1: Write `.gitignore`** — Cover Python, Docker, Terraform, K8s, IDE, OS files
- [ ] **Step 2: Write `.gitleaks.toml`** — Extend default ruleset; allowlist for docs/markdown
- [ ] **Step 3: Write `.pre-commit-config.yaml`** — Hooks: terraform_fmt, terraform_validate, helm_lint, kustomize_build, opa_test, yamllint, ruff, mypy, gitleaks, hadolint
- [ ] **Step 4: Write `Makefile`** — Targets: `validate`, `lint`, `test`, `docker-build`, `deploy-local`, `bootstrap`, `plan`, `clean`
- [ ] **Step 5: Write `README.md`** — Project overview, architecture diagram, quick start, prerequisites
- [ ] **Step 6: Write documentation stubs** — SETUP.md, RUNBOOK.md, ARCHITECTURE.md, SECURITY.md, TROUBLESHOOTING.md
- [ ] **Step 7: Run pre-commit install** — `pre-commit install && pre-commit run --all-files`
- [ ] **Step 8: Commit**

```bash
git add .gitignore .gitleaks.toml .pre-commit-config.yaml Makefile README.md docs/
git commit -m "chore: scaffold repository with tooling and documentation"
```

---

## Task 2: Application Code (FastAPI + OTel)

**Files:**
- Create: `app/Dockerfile`
- Create: `app/requirements.txt`
- Create: `app/pyproject.toml`
- Create: `app/.env.example`
- Create: `app/src/main.py`
- Create: `app/src/routers/__init__.py`
- Create: `app/src/routers/health.py`
- Create: `app/src/routers/items.py`
- Create: `app/src/services/__init__.py`
- Create: `app/src/services/item_service.py`
- Create: `app/src/models/__init__.py`
- Create: `app/src/models/item.py`
- Create: `app/src/telemetry/__init__.py`
- Create: `app/src/telemetry/logging.py`
- Create: `app/src/telemetry/metrics.py`
- Create: `app/src/telemetry/tracing.py`
- Create: `app/tests/__init__.py`
- Create: `app/tests/conftest.py`
- Create: `app/tests/test_health.py`
- Create: `app/tests/test_items.py`

**Interfaces:**
- Consumes: None (leaf)
- Produces: Docker image, Python package, test suite

- [ ] **Step 1: Write failing tests** — `test_health.py` (liveness/readiness), `test_items.py` (CRUD)
- [ ] **Step 2: Run tests to verify fail** — `pytest app/tests/ -v`
- [ ] **Step 3: Implement FastAPI app** — Structured logging, OTel tracing, Prometheus metrics, health endpoints, CRUD API
- [ ] **Step 4: Write `Dockerfile`** — Multi-stage, non-root user, distroless-ish, healthcheck, OCI labels
- [ ] **Step 5: Write `requirements.txt` + `pyproject.toml`** — Pinned versions, dev deps
- [ ] **Step 6: Run tests to verify pass** — `pytest app/tests/ -v --cov=app/src`
- [ ] **Step 7: Build Docker image locally** — `make docker-build` (uses GHCR for local)
- [ ] **Step 8: Commit**

```bash
git add app/
git commit -m "feat: add sample FastAPI application with OTel, Prometheus, structured logging"
```

---

## Task 3: Helm Chart (Application Packaging)

**Files:**
- Create: `helm/blueprint-app/Chart.yaml`
- Create: `helm/blueprint-app/values.yaml`
- Create: `helm/blueprint-app/values-dev.yaml`
- Create: `helm/blueprint-app/values-staging.yaml`
- Create: `helm/blueprint-app/values-production.yaml`
- Create: `helm/blueprint-app/templates/_helpers.tpl`
- Create: `helm/blueprint-app/templates/deployment.yaml`
- Create: `helm/blueprint-app/templates/service.yaml`
- Create: `helm/blueprint-app/templates/hpa.yaml`
- Create: `helm/blueprint-app/templates/ingress.yaml`
- Create: `helm/blueprint-app/templates/configmap.yaml`
- Create: `helm/blueprint-app/templates/secret.yaml`
- Create: `helm/blueprint-app/templates/serviceaccount.yaml`
- Create: `helm/blueprint-app/templates/rollout.yaml`
- Create: `helm/blueprint-app/templates/analysis-template.yaml`
- Create: `helm/blueprint-app/templates/pdb.yaml`
- Create: `helm/blueprint-app/templates/servicemonitor.yaml`

**Interfaces:**
- Consumes: Application Docker image (from CI)
- Produces: Renderable K8s manifests for Argo CD

- [ ] **Step 1: Write `Chart.yaml`** — Metadata, version, appVersion, dependencies (none)
- [ ] **Step 2: Write `values.yaml`** — Defaults: image, resources, probes, replicaCount, autoscaling, ingress, monitoring
- [ ] **Step 3: Write env-specific values** — `values-dev.yaml` (1 replica, debug), `values-staging.yaml` (2 replicas), `values-production.yaml` (3+ replicas, canary rollout, strict resources)
- [ ] **Step 4: Write `_helpers.tpl`** — Common template functions (name, labels, fullname)
- [ ] **Step 5: Write `deployment.yaml`** — Standard Deployment (used by dev/staging); production uses Rollout
- [ ] **Step 6: Write `rollout.yaml`** — Argo Rollout with canary steps (10%→30%→50%→100%), analysis templates
- [ ] **Step 7: Write `analysis-template.yaml`** — Prometheus queries for error rate + p99 latency
- [ ] **Step 8: Write remaining templates** — service, hpa, ingress, configmap, secret (ExternalSecret ref), serviceaccount, pdb, servicemonitor
- [ ] **Step 9: Validate** — `helm lint helm/blueprint-app && helm template test helm/blueprint-app -f helm/blueprint-app/values-dev.yaml`
- [ ] **Step 10: Commit**

```bash
git add helm/
git commit -m "feat: add Helm chart for blueprint-app with dev/staging/prod values and Argo Rollout"
```

---

## Task 4: Terraform Infrastructure (AWS Foundation)

**Files:**
- Create: `terraform/main.tf`
- Create: `terraform/variables.tf`
- Create: `terraform/outputs.tf`
- Create: `terraform/versions.tf`
- Create: `terraform/providers.tf`
- Create: `terraform/backend.tf`
- Create: `terraform/modules/vpc/main.tf` + `variables.tf` + `outputs.tf`
- Create: `terraform/modules/eks/main.tf` + `variables.tf` + `outputs.tf` + `iam.tf`
- Create: `terraform/modules/ecr/main.tf` + `variables.tf` + `outputs.tf`
- Create: `terraform/modules/iam/main.tf` + `variables.tf` + `outputs.tf` (OIDC provider, GitHub Actions role, IRSA roles)
- Create: `terraform/modules/argocd/main.tf` + `variables.tf` + `outputs.tf` (Helm release, bootstrap)
- Create: `terraform/modules/alb-controller/main.tf` + `variables.tf` + `outputs.tf`
- Create: `terraform/modules/external-secrets/main.tf` + `variables.tf` + `outputs.tf`
- Create: `terraform/modules/monitoring/main.tf` + `variables.tf` + `outputs.tf` (optional)
- Create: `terraform/environments/dev/main.tf` + `terraform.tfvars`
- Create: `terraform/environments/staging/main.tf` + `terraform.tfvars`
- Create: `terraform/environments/prod/main.tf` + `terraform.tfvars`

**Interfaces:**
- Consumes: AWS credentials (OIDC), Terraform state backend (S3/DynamoDB)
- Produces: VPC, EKS cluster, ECR repos, IAM roles, Argo CD, ALB controller, External Secrets Operator

- [ ] **Step 1: Write `versions.tf` + `providers.tf`** — Required providers, versions, aliases
- [ ] **Step 2: Write `backend.tf`** — S3 bucket + DynamoDB locking (commented for local)
- [ ] **Step 3: Write `variables.tf` + `outputs.tf`** — Root module inputs/outputs
- [ ] **Step 4: Write `main.tf`** — Module composition, data sources
- [ ] **Step 5: Write VPC module** — 3 AZs, public/private subnets, NAT GW, VPC endpoints (ECR, S3, SSM)
- [ ] **Step 6: Write EKS module** — Cluster (private endpoint), managed node groups (spot for dev), IRSA enabled, add-ons (vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver)
- [ ] **Step 7: Write ECR module** — Repos per app, lifecycle policy, scan-on-push, tag immutability
- [ ] **Step 8: Write IAM module** — OIDC provider for GitHub Actions, role with ECR push + EKS describe, IRSA roles for External Secrets, ALB Controller, Cert Manager
- [ ] **Step 9: Write Argo CD module** — Helm release (pinned v2.14+), namespace, RBAC, SSO config placeholder
- [ ] **Step 10: Write ALB Controller module** — Helm release, IRSA, ingress class
- [ ] **Step 11: Write External Secrets module** — Helm release, ClusterSecretStore (AWS SM), IRSA
- [ ] **Step 12: Write env tfvars** — Dev: small nodes, spot; Staging: on-demand; Prod: on-demand, multi-AZ
- [ ] **Step 13: Validate** — `cd terraform && terraform fmt -check && terraform init -backend=false && terraform validate`
- [ ] **Step 14: Commit**

```bash
git add terraform/
git commit -m "feat: add Terraform infrastructure for EKS, ECR, IAM, Argo CD, ALB, External Secrets"
```

---

## Task 5: GitOps Configuration (Argo CD Day 2+)

**Files:**
- Create: `gitops/argocd/projects/platform.yaml`
- Create: `gitops/argocd/projects/workloads.yaml`
- Create: `gitops/argocd/applicationsets/apps-dev.yaml`
- Create: `gitops/argocd/applicationsets/apps-staging.yaml`
- Create: `gitops/argocd/applicationsets/apps-production.yaml`
- Create: `gitops/argocd/argocd-cm.yaml`
- Create: `gitops/apps/blueprint-app/overlays/dev/kustomization.yaml`
- Create: `gitops/apps/blueprint-app/overlays/dev/values.yaml`
- Create: `gitops/apps/blueprint-app/overlays/staging/kustomization.yaml`
- Create: `gitops/apps/blueprint-app/overlays/staging/values.yaml`
- Create: `gitops/apps/blueprint-app/overlays/production/kustomization.yaml`
- Create: `gitops/apps/blueprint-app/overlays/production/values.yaml`
- Create: `gitops/apps/blueprint-app/values/values-dev.yaml`
- Create: `gitops/apps/blueprint-app/values/values-staging.yaml`
- Create: `gitops/apps/blueprint-app/values/values-production.yaml`
- Create: `gitops/clusters/eks-prod/cluster-secret.yaml`

**Interfaces:**
- Consumes: Helm chart (from `helm/`), GitOps repo values
- Produces: Argo CD Applications/ApplicationSets, AppProjects

- [ ] **Step 1: Write AppProjects** — `platform` (cluster-scoped, admin), `workloads` (namespace-scoped, dev/staging/prod)
- [ ] **Step 2: Write ApplicationSets** — Matrix generator (values dir × cluster label), per-environment sync policy
- [ ] **Step 3: Write Argo CD ConfigMap** — Repository credentials (GitHub App/token), Kustomize/Helm options, resource overrides
- [ ] **Step 4: Write Kustomize overlays** — Each env patches: replicaCount, resources, image.tag (from values), ingress host
- [ ] **Step 5: Write values files** — Mirror Helm values-dev/staging/prod.yaml but in GitOps repo (CI updates these)
- [ ] **Step 6: Write cluster secret** — For multi-cluster (placeholder)
- [ ] **Step 7: Validate** — `kustomize build gitops/apps/blueprint-app/overlays/dev` and each env
- [ ] **Step 8: Commit**

```bash
git add gitops/
git commit -m "feat: add GitOps config with Argo CD AppProjects, ApplicationSets, Kustomize overlays"
```

---

## Task 6: GitHub Actions CI/CD Workflows

**Files:**
- Create: `.github/workflows/ci.yaml`
- Create: `.github/workflows/cd-update-gitops.yaml`
- Create: `.github/workflows/cd-production.yaml`
- Create: `.github/workflows/security-scan.yaml`
- Create: `.github/dependabot.yaml`

**Interfaces:**
- Consumes: App code, Dockerfile, Helm chart, Terraform
- Produces: Docker image in ECR, updated GitOps values files, security reports

- [ ] **Step 1: Write `ci.yaml`** — Jobs: detect-changes → lint-test → build-push-ecr → trivy-scan → sbom → cosign-sign → gitleaks → codeql → summary
- [ ] **Step 2: Write `cd-update-gitops.yaml`** — Triggered by CI success; updates `gitops/apps/blueprint-app/values/values-dev.yaml` (and staging) with new image tag; commits to GitOps repo
- [ ] **Step 3: Write `cd-production.yaml`** — Manual dispatch with 2-reviewer approval (GH environment); canary weight input; promotes via Argo CD Rollout; auto-rollback on analysis fail
- [ ] **Step 4: Write `security-scan.yaml`** — Weekly + PR: gitleaks, trivy-fs, opa-test, license-check
- [ ] **Step 5: Write `dependabot.yaml`** — Weekly updates for pip, docker, github-actions, terraform
- [ ] **Step 6: Validate** — `yamllint .github/workflows/` and check syntax
- [ ] **Step 7: Commit**

```bash
git add .github/
git commit -m "feat: add GitHub Actions CI/CD with ECR, GitOps update, canary production, security scans"
```

---

## Task 7: Security Policies (OPA/Gatekeeper, Trivy, Cosign)

**Files:**
- Create: `security/opa/policies/deny_privileged.rego`
- Create: `security/opa/policies/require_resources.rego`
- Create: `security/opa/policies/require_image_source.rego`
- Create: `security/opa/policies/require_labels.rego`
- Create: `security/opa/policies/require_signed_images.rego`
- Create: `security/opa/tests/deny_privileged_test.rego`
- Create: `security/opa/tests/require_resources_test.rego`
- Create: `security/opa/tests/require_image_source_test.rego`
- Create: `security/opa/tests/require_labels_test.rego`
- Create: `security/opa/tests/require_signed_images_test.rego`
- Create: `security/trivy/trivy-operator.yaml`
- Create: `security/trivy/scan-schedule.yaml`
- Create: `security/cosign/cosign-keypair.yaml`
- Create: `security/cosign/verify-policy.yaml`
- Create: `security/vault/vault-config.yaml`
- Create: `security/vault/policies/app-policy.hcl`
- Create: `security/vault/policies/argocd-policy.hcl`

**Interfaces:**
- Consumes: K8s admission requests, container images
- Produces: Policy decisions, scan results, signed images

- [ ] **Step 1: Write OPA policies** — Deny privileged, require resources (dev: warn, prod: deny), require approved registries (ECR), require labels, require cosign signature (prod)
- [ ] **Step 2: Write OPA tests** — Positive/negative cases for each policy
- [ ] **Step 3: Write Trivy Operator config** — Scan jobs, schedule, target namespaces
- [ ] **Step 4: Write Cosign keypair + verify policy** — Demo keypair (prod: KMS); policy for admission
- [ ] **Step 5: Write Vault config** — Demo only (AWS SM preferred)
- [ ] **Step 6: Validate** — `opa test security/opa/tests/ security/opa/policies/ -v`
- [ ] **Step 7: Commit**

```bash
git add security/
git commit -m "feat: add OPA policies, Trivy Operator, Cosign signing, Vault config"
```

---

## Task 8: Observability Stack

**Files:**
- Create: `observability/prometheus/prometheus.yaml`
- Create: `observability/prometheus/alerting-rules.yaml`
- Create: `observability/prometheus/servicemonitor.yaml`
- Create: `observability/grafana/dashboards/app-overview.json`
- Create: `observability/grafana/dashboards/kubernetes-cluster.json`
- Create: `observability/grafana/dashboards/argocd.json`
- Create: `observability/grafana/provisioning/datasources.yaml`
- Create: `observability/grafana/provisioning/dashboards.yaml`
- Create: `observability/loki/loki-config.yaml`
- Create: `observability/tempo/tempo-config.yaml`
- Create: `observability/opentelemetry/otel-collector.yaml`
- Create: `observability/alertmanager/alertmanager.yaml`

**Interfaces:**
- Consumes: App metrics/logs/traces, K8s metrics
- Produces: Dashboards, alerts, stored telemetry

- [ ] **Step 1: Write Prometheus config** — Scrape configs for app, kube-state-metrics, node-exporter, cadvisor, otel-collector
- [ ] **Step 2: Write alerting rules** — High error rate, latency, crashloop, CPU/memory, pod not ready, replica mismatch, cert expiry
- [ ] **Step 3: Write Grafana provisioning** — Datasources (Prometheus, Loki, Tempo), dashboard auto-load
- [ ] **Step 4: Write dashboards** — App overview (RED), K8s cluster, Argo CD
- [ ] **Step 5: Write Loki + Tempo + OTel Collector** — Log aggregation, trace storage, collection pipeline
- [ ] **Step 6: Write Alertmanager** — Routes, receivers (Slack placeholder), inhibition rules
- [ ] **Step 7: Validate** — `yamllint` on all YAML; `promtool check rules` on alerting rules
- [ ] **Step 8: Commit**

```bash
git add observability/
git commit -m "feat: add observability stack (Prometheus, Grafana, Loki, Tempo, OTel, Alertmanager)"
```

---

## Task 9: Local Validation Scripts & Bootstrap

**Files:**
- Create: `scripts/bootstrap.sh`
- Create: `scripts/validate.sh`
- Create: `scripts/deploy-local.sh`
- Create: `scripts/rollback.sh`

**Interfaces:**
- Consumes: Local k3d cluster, Helm chart, Kustomize overlays
- Produces: Validated deployment, rollback capability

- [ ] **Step 1: Write `bootstrap.sh`** — Create k3d cluster, install Argo CD, CRDs (Rollout, Gateway), deploy monitoring stack
- [ ] **Step 2: Write `validate.sh`** — Run all lints: terraform, helm, kustomize, opa, yamllint, hadolint, ruff, mypy, gitleaks
- [ ] **Step 3: Write `deploy-local.sh`** — Deploy Helm chart to k3d with dev values; verify pods, health endpoints
- [ ] **Step 4: Write `rollback.sh`** — Git-based rollback: `git revert` + push → Argo CD syncs
- [ ] **Step 5: Test on k3d** — Run `make bootstrap && make validate && make deploy-local`
- [ ] **Step 6: Commit**

```bash
git add scripts/
git commit -m "feat: add bootstrap, validation, local deploy, and rollback scripts"
```

---

## Task 10: End-to-End Integration Test & Documentation Polish

**Files:**
- Modify: `docs/SETUP.md` (complete)
- Modify: `docs/RUNBOOK.md` (complete)
- Modify: `docs/ARCHITECTURE.md` (complete)
- Modify: `docs/SECURITY.md` (complete)
- Modify: `docs/TROUBLESHOOTING.md` (complete)
- Modify: `README.md` (final)

**Interfaces:**
- Consumes: All previous tasks
- Produces: Complete, verified, documented platform

- [ ] **Step 1: Run full validation** — `make validate` (all lints pass)
- [ ] **Step 2: Deploy to k3d** — `make deploy-local`; verify app health, metrics, traces, logs
- [ ] **Step 3: Test rollback** — `make rollback`; verify previous version restored
- [ ] **Step 4: Complete documentation** — Fill in SETUP.md (prerequisites, steps), RUNBOOK.md (procedures), ARCHITECTURE.md (diagrams), SECURITY.md (controls), TROUBLESHOOTING.md (common issues)
- [ ] **Step 5: Final README** — Badges, architecture, quick start, directory structure, links to docs
- [ ] **Step 6: Commit**

```bash
git add docs/ README.md
git commit -m "docs: complete all documentation; chore: final polish"
```

---

## Execution Recommendation

**Use Subagent-driven development** because:
- 10 tasks with clear boundaries and minimal cross-task interface coupling
- Each task produces independently testable deliverable
- Mistakes in Terraform or Helm would be costly to debug later
- Fresh reviewer per task catches design drift early

Does this plan capture what you want? If yes, I'll begin implementation with superpowers:subagent-driven-development.