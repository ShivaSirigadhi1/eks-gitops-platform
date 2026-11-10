#!/usr/bin/env bash
# Rollback helper — rolls back an Argo CD application to previous revision
# Usage: ./scripts/rollback.sh <environment> [revision]

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <environment> [revision]"
    echo "  environment: dev | staging | production"
    echo "  revision:    ArgoCD revision number (default: previous)"
    exit 1
fi

ENVIRONMENT="$1"
REVISION="${2:-}"
ARGOCD_SERVER="${ARGOCD_SERVER:-argocd.example.com}"
ARGOCD_AUTH_TOKEN="${ARGOCD_AUTH_TOKEN:-}"

case "$ENVIRONMENT" in
    dev)
        APP_NAME="blueprint-app-dev"
        NAMESPACE="blueprint-dev"
        ;;
    staging)
        APP_NAME="blueprint-app-staging"
        NAMESPACE="blueprint-staging"
        ;;
    production)
        APP_NAME="blueprint-app-production"
        NAMESPACE="blueprint-production"
        ;;
    *)
        echo "Unknown environment: $ENVIRONMENT"
        exit 1
        ;;
esac

echo "=== Rolling back $ENVIRONMENT ==="

argocd app get "$APP_NAME" \
    --server "$ARGOCD_SERVER" \
    --auth-token "$ARGOCD_AUTH_TOKEN" \
    --insecure

ROLLBACK_ARGS=("$APP_NAME" "--server" "$ARGOCD_SERVER" "--auth-token" "$ARGOCD_AUTH_TOKEN" "--insecure")
if [[ -n "$REVISION" ]]; then
    ROLLBACK_ARGS+=("$REVISION")
fi

argocd app rollback "${ROLLBACK_ARGS[@]}"

kubectl rollout status deployment/blueprint-app -n "$NAMESPACE" --timeout=600s

echo "=== Rollback complete ==="
