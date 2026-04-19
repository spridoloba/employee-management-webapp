#!/usr/bin/env bash
# Install cluster-wide controllers: ingress-nginx, cert-manager, sealed-secrets.
# Idempotent — safe to re-run. Run once per cluster (Kind or AKS).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INGRESS_NGINX_VERSION="${INGRESS_NGINX_VERSION:-4.11.3}"
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.16.1}"
SEALED_SECRETS_VERSION="${SEALED_SECRETS_VERSION:-2.16.1}"

log() { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }

log "Adding Helm repositories"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null
helm repo add jetstack https://charts.jetstack.io >/dev/null
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets >/dev/null
helm repo update >/dev/null

log "Installing ingress-nginx"
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --version "${INGRESS_NGINX_VERSION}" \
  -f "${SCRIPT_DIR}/ingress-nginx-values.yaml" \
  --wait

log "Installing cert-manager"
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version "${CERT_MANAGER_VERSION}" \
  -f "${SCRIPT_DIR}/cert-manager-values.yaml" \
  --wait

log "Installing sealed-secrets controller"
helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace sealed-secrets --create-namespace \
  --version "${SEALED_SECRETS_VERSION}" \
  -f "${SCRIPT_DIR}/sealed-secrets-values.yaml" \
  --wait

log "Applying ClusterIssuers (cert-manager)"
kubectl apply -f "${SCRIPT_DIR}/cluster-issuer-staging.yaml"
kubectl apply -f "${SCRIPT_DIR}/cluster-issuer-prod.yaml"

log "Bootstrap complete."
