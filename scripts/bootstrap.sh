#!/usr/bin/env bash
# Bootstrap script — creates local k3d cluster and installs Argo CD
# Usage: ./scripts/bootstrap.sh

set -euo pipefail

CLUSTER_NAME="gitops-lab"
ARGOCD_VERSION="v2.14.4"

echo "=============================================="
echo "  EKS GitOps Platform — Local Bootstrap"
echo "=============================================="
echo ""

# Check prerequisites
for cmd in k3d kubectl helm argocd; do
    if ! command -v $cmd &> /dev/null; then
        echo "ERROR: $cmd not found. Please install it first."
        exit 1
    fi
done

# Create k3d cluster
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "Cluster $CLUSTER_NAME already exists"
else
    echo "Creating k3d cluster: $CLUSTER_NAME"
    k3d cluster create $CLUSTER_NAME \
        --servers 1 \
        --agents 2 \
        --port "80:80@loadbalancer" \
        --port "443:443@loadbalancer" \
        --k3s-arg "--disable=traefik@server:*" \
        --wait
fi

# Install Argo CD
echo "Installing Argo CD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml

# Wait for Argo CD to be ready
echo "Waiting for Argo CD pods..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# Get initial admin password
echo ""
echo "Argo CD initial admin password:"
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
echo ""

echo "Bootstrap complete!"
echo "Access Argo CD UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Then open https://localhost:8080"
