#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# bootstrap.sh — Bootstrap ArgoCD
# Usage: ./bootstrap.sh
#
# Prerequisites: kubectl pointing to the target cluster
# ============================================================

ARGO_NAMESPACE="argocd"

echo "=== Step 1: Install ArgoCD ==="
kubectl create namespace "$ARGO_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n "$ARGO_NAMESPACE" --server-side --force-conflicts -f "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

echo "Waiting for ArgoCD components to be ready..."
kubectl wait --for=condition=Available -n "$ARGO_NAMESPACE" deployment/argocd-server --timeout=120s
kubectl wait --for=condition=Available -n "$ARGO_NAMESPACE" deployment/argocd-repo-server --timeout=60s
kubectl wait --for=condition=Available -n "$ARGO_NAMESPACE" deployment/argocd-redis --timeout=60s
kubectl wait --for=condition=Available -n "$ARGO_NAMESPACE" deployment/argocd-applicationset-controller --timeout=60s
echo "  ArgoCD is ready."

echo ""
echo "=== Step 2: Apply ArgoCD root-app ==="
kubectl apply -f gitops/root-app.yaml

echo ""
echo "=== Step 3: Wait for root-app to sync ==="
echo "  Run: kubectl get applications -n argocd -w"
echo ""
echo "=== Done ==="
echo "  Access ArgoCD UI:     kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "  Get admin password:   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath={.data.password} | base64 -d"
echo ""

# Note: CRDs and operators are managed by ArgoCD via the root-app.
# The root-app deploys CRD-only Applications (wave -2) and operator
# Applications (wave -1) in the correct namespaces.
# See gitops/children/ for the full resource tree.
