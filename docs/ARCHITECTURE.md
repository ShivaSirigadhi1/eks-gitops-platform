# Architecture

## CI/CD Pipeline Flow

```mermaid
graph TD
    A[Developer Push] --> B[GitHub Actions CI]
    B --> C{Lint & Test}
    C -->|Pass| D[Build Docker Image]
    C -->|Fail| E[Notification]
    D --> F[Trivy Scan]
    D --> G[SBOM Generation]
    D --> H[Cosign Sign]
    D --> I[Push to Registry]
    F --> J[Security Tab]
    G --> K[Artifact Storage]
    H --> L[Signature Verification]
    I --> M[Update GitOps Repo]
    M --> N[Argo CD Sync]
    N --> O[Dev Environment]
    O --> P[Smoke Tests]
    P --> Q{Promote?}
    Q -->|Manual| R[Staging]
    R --> S[Integration Tests]
    S --> T{2-Reviewer Approval?}
    T -->|Yes| U[Production Canary]
    U --> V[Health Check]
    V -->|Pass| W[Full Rollout]
    V -->|Fail| X[Auto-Rollback]
```

## Observability Pipeline

```mermaid
graph LR
    A[FastAPI App] -->|OTLP| B[OTel Collector]
    A -->|/metrics| C[Prometheus]
    B --> D{Jaeger/OTel Pipelines}
    D -->|Traces| E[Jaeger]
    D -->|Traces| F[Tempo]
    D -->|Metrics| G[Prometheus]
    D -->|Logs| H[Loki]
    C --> I[Grafana]
    E --> I
    F --> I
    H --> I
    G --> J[Alertmanager]
    J --> K[Slack / PagerDuty]
```

## Security Layers

```mermaid
graph TD
    A[Code Push] --> B[CI Security Checks]
    B --> B1[Gitleaks - Secrets]
    B --> B2[CodeQL - SAST]
    B --> B3[Trivy - Container Scan]
    B --> B4[Syft - SBOM]
    B --> B5[Cosign - Sign]
    C[K8s Admission] --> D[OPA Policies]
    D --> D1[Deny Privileged]
    D --> D2[Require Resource Limits]
    D --> D3[Require Labels]
    D --> D4[Verify Image Source]
    D --> D5[Verify Signature]
    E[Runtime] --> F[Trivy Operator]
    E --> G[Cosign Verify]
    E --> H[Dependabot]
```

## Component Relationships

### Application Layer
- **FastAPI** serves HTTP endpoints with Prometheus metrics on `/metrics` and OTel traces sent via OTLP
- **structlog** provides structured JSON logging to stdout
- **Health probes** (`/healthz`, `/readyz`) enable Kubernetes liveness/readiness checks

### CI/CD Layer
- **GitHub Actions** orchestrates the entire pipeline with concurrency control
- **Docker Buildx** builds multi-arch images (amd64 + arm64) with layer caching
- **Argo CD** syncs the Helm chart to the target cluster via GitOps

### Kubernetes Layer
- **Helm** manages application configuration via values files per environment
- **HPA** auto-scales based on CPU (70%) and memory (80%)
- **PDB** ensures minimum availability during disruptions
- **TopologySpreadConstraints** distributes pods across zones and nodes

### Observability Layer
- **OTel Collector** receives OTLP data, processes, and fans out to backends
- **Prometheus** scrapes metrics from the app, kube-state-metrics, and node-exporter
- **Grafana** provides dashboards with Prometheus, Loki, and Tempo datasources
- **Alertmanager** routes alerts by severity with Slack integration

### Security Layer
- **OPA** enforces admission policies on all Kubernetes resources
- **Trivy** scans containers at build time and continuously in the cluster
- **Cosign** signs container images for supply chain integrity
- **Vault** manages secrets with dynamic database credentials
