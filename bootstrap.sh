#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# bootstrap.sh — Bootstrap ArgoCD and install all CRDs
# Usage: ./bootstrap.sh
#
# Prerequisites: kubectl pointing to the target cluster
# ============================================================

ARGO_NAMESPACE="argocd"
ARGO_VERSION="v2.14.0"  # check latest at https://github.com/argoproj/argo-cd/releases

echo "=== Step 1: Install ArgoCD ==="
kubectl create namespace "$ARGO_NAMESPACE"
kubectl apply -n "$ARGO_NAMESPACE" --server-side --force-conflicts -f "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

echo "Waiting for ArgoCD components to be ready..."
kubectl wait --for=condition=Available -n "$ARGO_NAMESPACE" deployment/argocd-server --timeout=120s
kubectl wait --for=condition=Available -n "$ARGO_NAMESPACE" deployment/argocd-repo-server --timeout=60s
kubectl wait --for=condition=Available -n "$ARGO_NAMESPACE" deployment/argocd-redis --timeout=60s
kubectl wait --for=condition=Available -n "$ARGO_NAMESPACE" deployment/argocd-applicationset-controller --timeout=60s
echo "  ArgoCD is ready."

echo ""
echo "=== Step 2: Install CRDs (before any ArgoCD app syncs) ==="

# Add all required Helm repos
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo add strimzi https://strimzi.io/charts --force-update
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo add istio https://istio-release.storage.googleapis.com/charts --force-update
helm repo add elastic https://helm.elastic.co --force-update
helm repo add zalando https://opensource.zalando.com/postgres-operator/charts/postgres-operator --force-update
helm repo add grafana https://grafana.github.io/helm-charts --force-update
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts --force-update
helm repo add kiali https://kiali.org/helm-charts --force-update
helm repo add traefik https://traefik.github.io/charts --force-update
helm repo update

install_crds() {
  local name="$1" chart="$2" repo="$3" version="$4"
  echo "  Installing CRDs from $name ($version)..."
  helm template "$name" "$chart" --repo "$repo" --version "$version" "${@:5}" 2>/dev/null | \
    kubectl apply --server-side -f - 2>/dev/null || true
}

# Cert-manager CRDs
install_crds "cert-manager" "cert-manager" "https://charts.jetstack.io" "v1.12.0" \
  --set installCRDs=true

# Strimzi CRDs (extracted via helm template on the strimzi-kafka-operator chart)
install_crds "strimzi" "strimzi-kafka-operator" "https://strimzi.io/charts" "0.35.1"

# Prometheus operator CRDs
install_crds "prometheus" "kube-prometheus-stack" "https://prometheus-community.github.io/helm-charts" "85.0.1" \
  --set crds.enabled=true

# Istio CRDs (from the istio-base chart which includes them)
install_crds "istio-base" "base" "https://istio-release.storage.googleapis.com/charts" "1.29.2"

# Traefik CRDs (from the traefik-crd chart)
install_crds "traefik-crd" "traefik-crd" "https://traefik.github.io/charts" "39.0.7"

# ECK operator CRDs
install_crds "eck" "eck-operator" "https://helm.elastic.co" "3.4.0" \
  --set installCRDs=true

# Postgres operator CRDs
install_crds "postgres-operator" "postgres-operator" "https://opensource.zalando.com/postgres-operator/charts/postgres-operator" "1.15.1"

# Grafana operator CRDs
install_crds "grafana-operator" "grafana-operator" "https://grafana.github.io/helm-charts" "v5.0.2"

# OpenTelemetry operator CRDs
install_crds "opentelemetry-operator" "opentelemetry-operator" "https://open-telemetry.github.io/opentelemetry-helm-charts" "0.112.1"

# Kiali operator CRD
install_crds "kiali-operator" "kiali-operator" "https://kiali.org/helm-charts" "2.25.0"

echo "  All CRDs installed."

echo ""
echo "=== Step 3: Apply ArgoCD root-app ==="
kubectl apply -f gitops/root-app.yaml

echo ""
echo "=== Step 4: Wait for root-app to sync ==="
echo "  Run: kubectl get applications -n argocd -w"
echo ""
echo "=== Done ==="
echo "  Access ArgoCD UI:     kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "  Get admin password:   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath={.data.password} | base64 -d"
echo ""
