# Troubleshooting Guide

## Common Issues & Solutions

### Terraform

#### "Error: InvalidClientTokenId"
```bash
# AWS credentials not configured or expired
aws configure
# Or use SSO
aws sso login
```

#### "Error: waiting for EKS cluster creation"
```bash
# Check CloudFormation events
aws cloudformation describe-stack-events --stack-name <stack-name>

# Common: IAM role limits, VPC quota, KMS key policy
```

#### "Error: provider configuration not present"
```bash
# Run terraform init first
cd terraform && terraform init
```

### Argo CD

#### Application stuck in "Progressing"
```bash
# Check application status
argocd app get <app-name>

# Common causes:
# 1. Helm chart not found - check repo URL and chart name
# 2. Values file missing - check path in GitOps repo
# 3. CRD not installed - install Argo Rollouts CRDs
```

#### Application "OutOfSync" but won't sync
```bash
# Check sync policy
argocd app get <app-name> -o yaml | grep -A 20 syncPolicy

# Force sync
argocd app sync <app-name> --prune

# Check resource differences
argocd app diff <app-name>
```

#### "Application namespace not found"
```bash
# Ensure CreateNamespace=true in syncOptions
# Or create namespace manually
kubectl create namespace blueprint-dev
```

### GitHub Actions

#### "Error: ECR login failed"
```bash
# Check OIDC role trust policy
# Verify GitHub repo pattern matches
# Check IAM role has ECR permissions
```

#### "Error: GitOps repo push failed"
```bash
# Check GITOPS_PAT secret exists and has repo scope
# Verify repo name in workflow matches actual repo
```

#### "Error: Trivy scan failed"
```bash
# Check image exists in registry
docker pull ghcr.io/your-org/blueprint-app:sha-abc1234

# Trivy may need network access for vulnerability DB
```

### Kubernetes

#### Pods in "CrashLoopBackOff"
```bash
# Check logs
kubectl logs -n <namespace> <pod-name> --previous

# Common causes:
# 1. OOMKilled - increase memory limit
# 2. Missing env vars - check ConfigMap/Secret
# 3. Port conflict - check containerPort
# 4. Health probe failing - check /healthz endpoint
```

#### Pods in "Pending"
```bash
# Check events
kubectl describe pod -n <namespace> <pod-name>

# Common causes:
# 1. Insufficient resources - check node capacity
# 2. Node selector/affinity mismatch
# 3. PVC not bound - check storage class
# 4. Taints/tolerations mismatch
```

#### HPA not scaling
```bash
# Check metrics server
kubectl top pods -n <namespace>

# Check HPA status
kubectl get hpa -n <namespace>
kubectl describe hpa -n <namespace> <hpa-name>

# Verify resource requests set on containers
```

### Networking

#### Ingress not working
```bash
# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check ingress status
kubectl get ingress -n <namespace>
kubectl describe ingress -n <namespace> <ingress-name>

# Verify security groups and target groups in AWS console
```

#### Service not accessible
```bash
# Check service endpoints
kubectl get endpoints -n <namespace>

# Check pod labels match service selector
kubectl get pods -n <namespace> --show-labels
```

### Argo Rollouts (Canary)

#### Canary stuck at weight
```bash
# Check analysis runs
kubectl get analysisrun -n <namespace>
kubectl describe analysisrun -n <namespace> <name>

# Common: Prometheus query returning no data
# Verify metrics endpoint and query syntax
```

#### Rollout not progressing
```bash
# Check rollout status
kubectl argo rollouts get rollout -n <namespace> <name>

# Check ReplicaSets
kubectl get rs -n <namespace>
```

### Monitoring

#### Prometheus not scraping
```bash
# Check ServiceMonitor
kubectl get servicemonitor -n <namespace>
kubectl describe servicemonitor -n <namespace> <name>

# Check Prometheus targets
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# Open http://localhost:9090/targets
```

#### Grafana dashboard empty
```bash
# Verify datasource configuration
# Check query syntax
# Verify label names match (namespace, pod, etc.)
```

#### Alerts not firing
```bash
# Check Alertmanager
kubectl port-forward svc/alertmanager 9093:9093 -n monitoring

# Check alert rules evaluation
# http://localhost:9090/rules (Prometheus)
```

## Debug Commands Quick Reference

```bash
# Cluster info
kubectl cluster-info
kubectl get nodes -o wide

# All resources in namespace
kubectl get all -n <namespace>

# Events (sorted by time)
kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp

# Resource usage
kubectl top nodes
kubectl top pods -n <namespace>

# Logs with timestamps
kubectl logs -n <namespace> <pod-name> --timestamps --since=1h

# Exec into pod
kubectl exec -it -n <namespace> <pod-name> -- /bin/sh

# Port forward
kubectl port-forward -n <namespace> svc/<service> 8080:80

# Describe any resource
kubectl describe <resource-type> <name> -n <namespace>

# Dry-run apply
kubectl apply -f <file.yaml> --dry-run=client -o yaml
```
