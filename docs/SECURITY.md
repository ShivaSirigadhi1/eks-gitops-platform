# Security Guide

## Security Architecture Overview

This platform implements defense-in-depth security across multiple layers:

```
┌─────────────────────────────────────────────────────────────────┐
│                        SECURITY LAYERS                          │
├─────────────────────────────────────────────────────────────────┤
│  CODE          │ Gitleaks, CodeQL, Dependabot                   │
├────────────────┼────────────────────────────────────────────────┤
│  CONTAINER     │ Trivy, Syft SBOM, Cosign Sign/Verify           │
├────────────────┼────────────────────────────────────────────────┤
│  ADMISSION     │ OPA/Gatekeeper (privileged, resources, labels, │
│  CONTROL       │   image source, signatures)                    │
├────────────────┼────────────────────────────────────────────────┤
│  RUNTIME       │ Trivy Operator, Falco (optional)               │
├────────────────┼────────────────────────────────────────────────┤
│  NETWORK       │ Private EKS, ALB with WAF, NetworkPolicy       │
├────────────────┼────────────────────────────────────────────────┤
│  IDENTITY      │ IRSA, OIDC GitHub Actions, AWS SSO             │
├────────────────┼────────────────────────────────────────────────┤
│  SECRETS       │ External Secrets → AWS Secrets Manager         │
└────────────────┴────────────────────────────────────────────────┘
```

## CI Security Checks

### Gitleaks (Secrets Scanning)
- Runs on every push and PR
- Scans entire git history
- Configured in `.gitleaks.toml` with allowlists for docs

### CodeQL (SAST)
- Analyzes Python code for security vulnerabilities
- Runs security-and-quality query suite
- Results in GitHub Security tab

### Trivy (Container Scanning)
- Scans built images for CVEs (CRITICAL, HIGH)
- Runs in CI and as scheduled CronJob in cluster
- Generates SARIF for GitHub Security tab

### SBOM Generation (Syft)
- Generates SPDX-format Software Bill of Materials
- Uploaded as CI artifact (30-day retention)
- Enables vulnerability tracking

### Image Signing (Cosign)
- Signs images with keyless or keypair signing
- Verification at admission (production) and runtime
- Demo uses keypair; production should use KMS/HSM

## Admission Control (OPA/Gatekeeper)

Policies in `security/opa/policies/`:

| Policy | Description | Action |
|--------|-------------|--------|
| `deny_privileged.rego` | Blocks privileged containers, root users, capability escalation | Deny |
| `require_resources.rego` | Requires CPU/memory requests and limits | Deny |
| `require_image_source.rego` | Only allows approved registries, blocks `:latest` in prod | Deny |
| `require_labels.rego` | Enforces standard Kubernetes labels | Deny |
| `require_signed_images.rego` | Requires Cosign signature in production | Deny |

### Testing Policies
```bash
# Run all tests
opa test security/opa/tests/ security/opa/policies/ -v

# Test specific policy
opa eval -i input.json -d security/opa/policies/require_resources.rego "data.kubernetes.admission.deny"
```

## Runtime Security

### Trivy Operator
- Scans running pods for vulnerabilities
- Creates `VulnerabilityReport` CRDs
- Generates Prometheus metrics for alerting
- Schedule: daily at 3 AM + on pod creation

### Network Policies
Default-deny ingress/egress per namespace:
```yaml
# Applied via Helm chart
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```

## Identity & Access Management

### GitHub Actions → AWS (OIDC)
- No long-lived AWS credentials in GitHub
- GitHub Actions requests JWT from OIDC provider
- AWS STS issues temporary credentials per workflow run
- Role: `github-actions` with ECR push + EKS describe permissions

### IRSA for Cluster Add-ons
- AWS Load Balancer Controller: ALB permissions
- External Secrets Operator: Secrets Manager read
- EBS CSI Driver: Volume management
- Cert Manager: ACM certificates

### Argo CD RBAC
- `platform` project: Full cluster access for platform team
- `workloads` project: Namespace-scoped for app teams
- SSO integration via Dex/OIDC (configured in Argo CD)

## Secrets Management

### External Secrets Operator
```yaml
# ClusterSecretStore points to AWS Secrets Manager
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets
```

### Secret Sync Pattern
1. Store secrets in AWS Secrets Manager (manual or via CI)
2. Create `ExternalSecret` CRD in GitOps repo
3. ESO syncs to native K8s Secret
4. Application mounts Secret as env vars or volume

### No Secrets in Git
- `.gitleaks.toml` prevents accidental commits
- Pre-commit hook runs gitleaks locally
- All secret references use ExternalSecret CRDs

## Compliance & Auditing

### Image Provenance
- Cosign signatures provide SLSA Level 2 compliance
- SBOM enables vulnerability tracking
- Trivy scans at build + runtime

### Audit Trail
- All deployments via GitOps = full Git history
- Argo CD tracks sync status and drift
- GitHub Actions workflow runs = CI audit log

### Compliance Checks
- License compliance in CI (pip-licenses)
- OPA policies enforce organizational standards
- Dependabot keeps dependencies updated
