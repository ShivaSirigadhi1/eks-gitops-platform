#!/usr/bin/env bash
# Deploy to local k3d cluster for validation
# Usage: ./scripts/deploy-local.sh [dev|staging|production]

set -euo pipefail

ENV="${1:-dev}"
CLUSTER_NAME="gitops-lab"

echo "=============================================="
echo "  Deploying to local k3d ($ENV)"
echo "=============================================="

# Ensure cluster exists
if ! k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "Cluster $CLUSTER_NAME not found. Run ./scripts/bootstrap.sh first."
    exit 1
fi

# Switch context
kubectl config use-context k3d-$CLUSTER_NAME

# Create namespaces
kubectl create namespace blueprint-$ENV --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Deploy monitoring stack (simplified)
echo "Deploying monitoring..."
kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/main/charts/kube-prometheus-stack/templates/servicemonitor.yaml 2>/dev/null || true

# Deploy app via Helm
echo "Deploying blueprint-app ($ENV)..."
helm upgrade --install blueprint-app-$ENV helm/blueprint-app \
    --namespace blueprint-$ENV \
    --create-namespace \
    -f helm/blueprint-app/values-${ENV}.yaml \
    --wait --timeout 5m

# Verify deployment
echo "Verifying deployment..."
kubectl rollout status deployment/blueprint-app -n blueprint-$ENV --timeout=300s
kubectl get pods -n blueprint-$ENV

# Port-forward for testing
echo ""
echo "To test the app, run:"
echo "  kubectl port-forward svc/blueprint-app-$ENV 8080:80 -n blueprint-$ENV"
echo "  Then curl http://localhost:8080/healthz"
