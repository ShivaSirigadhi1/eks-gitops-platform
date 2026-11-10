# Runbook — Operational Procedures

## Rolling Back a Deployment

### Via ArgoCD CLI
```bash
# List deployment history
argocd app get blueprint-app-production

# Rollback to previous revision
argocd app rollback blueprint-app-production

# Rollback to specific revision
argocd app rollback blueprint-app-production 3
```

### Via Rollback Script
```bash
# Rollback to previous revision
./scripts/rollback.sh production

# Rollback to specific revision
./scripts/rollback.sh production 3
```

### Via GitHub Actions
1. Go to Actions → "CD - Production Environment"
2. Click "Run workflow"
3. Enter the previous stable image tag
4. The canary deploy will automatically rollback if health checks fail

## Investigating a Failed CI Pipeline

### Common Failures and Fixes

| Failure | Likely Cause | Fix |
|---------|-------------|-----|
| `ruff` linting fails | Code style issues | Run `ruff check --fix` locally |
| `mypy` type checks fail | Type annotation errors | Fix type annotations |
| `pytest` tests fail | Test assertion errors | Check test output for details |
| `docker build` fails | Dockerfile or dependency issue | Check Dockerfile syntax |
| `trivy` scan fails | Critical/high vulnerabilities | Update dependencies |

### Re-run CI
```bash
# Push an empty commit to trigger CI
git commit --allow-empty -m "ci: trigger re-run"
git push origin main
```

## Responding to Critical Alerts

### High Error Rate (>5%)
1. **Check** Grafana dashboard for error rate spike
2. **Identify** affected endpoints via HTTP status code breakdown
3. **Check** application logs in Loki:
   ```logfmt
   {namespace="blueprint-production"} |= "error"
   ```
4. **Check** pod health:
   ```bash
   kubectl get pods -n blueprint-production
   kubectl logs -n blueprint-production deployment/blueprint-app
   ```
5. **If needed**, rollback the deployment

### Pod CrashLooping
1. **Check** pod status:
   ```bash
   kubectl describe pod -n blueprint-production <pod-name>
   ```
2. **View** recent logs:
   ```bash
   kubectl logs -n blueprint-production --previous <pod-name>
   ```
3. **Check** resource usage:
   ```bash
   kubectl top pod -n blueprint-production
   ```
4. **Common causes**: OOMKilled, missing config, init container failure

### High Latency (P99 > 2s)
1. **Check** Jaeger or Tempo for trace details
2. **Identify** slow endpoints via the Grafana dashboard
3. **Check** database/backend service latency
4. **Scale up** if under-provisioned:
   ```bash
   kubectl scale deployment/blueprint-app -n blueprint-production --replicas=5
   ```

## Rotating Secrets in Vault

```bash
# Authenticate to Vault
vault login -namespace=vault -method=kubernetes role=admin

# Generate new secret
vault kv put secret/blueprint-app/production \
    api_key=$(openssl rand -base64 32) \
    db_password=$(openssl rand -base64 32)

# Rotate database credentials
vault lease revoke -prefix database/creds/blueprint-app

# Restart pods to pick up new secrets
kubectl rollout restart deployment/blueprint-app -n blueprint-production
```

## Adding New Team Members to ArgoCD

```bash
# Create RBAC role in ArgoCD
argocd account update-password \
    --account developer \
    --new-password <secure-password>

# Assign permissions via project policy
argocd proj role create workloads \
    --role developer \
    --policy "applications,get,workloads/*,allow"
```

## Checking Security Scan Results

```bash
# View Trivy results in GitHub Security tab
# https://github.com/your-org/eks-gitops-platform/security/code-scanning

# Check OPA policy violations
kubectl get events --all-namespaces | grep -i "opa\|denied"

# View SBOM artifacts
# https://github.com/your-org/eks-gitops-platform/actions/artifacts
```

## Monitoring Alerts

```bash
# Check alertmanager status
kubectl port-forward svc/alertmanager 9093:9093 -n monitoring
# Open http://localhost:9093

# View active alerts
curl http://localhost:9093/api/v1/alerts | jq '.data[]'

# Check Prometheus rule evaluation
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# Open http://localhost:9090/rules
```
