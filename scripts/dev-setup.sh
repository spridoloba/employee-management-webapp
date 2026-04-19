#!/usr/bin/env bash
# Idempotent local Dev bootstrap:
#   1. create Kind cluster (if missing)
#   2. install cluster controllers (ingress-nginx, cert-manager, sealed-secrets)
#   3. install MySQL via Bitnami chart
#   4. create emapp namespace + app secret seeded from .env
#   5. deploy the emapp Helm chart with values-dev.yaml
#
# Re-running is safe: every step uses upgrade-or-create semantics.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CLUSTER_NAME="emapp"
APP_NAMESPACE="emapp"
MYSQL_RELEASE="mysql"
APP_RELEASE="emapp"
SECRET_NAME="emapp-secret"
ENV_FILE="${REPO_ROOT}/.env"

log() { printf '\033[1;34m[dev-setup]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[dev-setup ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

[[ -f "${ENV_FILE}" ]] || die ".env not found — copy .env.example to .env and fill it in"
# shellcheck source=/dev/null
set -a; . "${ENV_FILE}"; set +a
: "${DATABASE_NAME:?DATABASE_NAME not set in .env}"
: "${DATABASE_USERNAME:?DATABASE_USERNAME not set in .env}"
: "${DATABASE_PASSWORD:?DATABASE_PASSWORD not set in .env}"
: "${DATABASE_ROOT_PASSWORD:?DATABASE_ROOT_PASSWORD not set in .env}"

if ! kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  log "Creating Kind cluster '${CLUSTER_NAME}'"
  sudo mkdir -p /home/kind-storage/mysql
  kind create cluster --config "${REPO_ROOT}/k8s/kind/cluster.yaml"
else
  log "Kind cluster '${CLUSTER_NAME}' already exists — skipping creation"
fi
kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null

log "Installing cluster controllers"
"${REPO_ROOT}/k8s/bootstrap/install.sh"

log "Ensuring namespace '${APP_NAMESPACE}'"
kubectl get ns "${APP_NAMESPACE}" >/dev/null 2>&1 \
  || kubectl create ns "${APP_NAMESPACE}"

log "Adding Bitnami Helm repo"
helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null
helm repo update >/dev/null

log "Deploying MySQL (Bitnami chart, release '${MYSQL_RELEASE}')"
helm upgrade --install "${MYSQL_RELEASE}" bitnami/mysql \
  --namespace "${APP_NAMESPACE}" \
  --set auth.rootPassword="${DATABASE_ROOT_PASSWORD}" \
  --set auth.username="${DATABASE_USERNAME}" \
  --set auth.password="${DATABASE_PASSWORD}" \
  --set auth.database="${DATABASE_NAME}" \
  -f "${REPO_ROOT}/helm-charts/sqlvalues.yaml" \
  --wait

log "Creating/updating application secret '${SECRET_NAME}'"
kubectl create secret generic "${SECRET_NAME}" \
  --namespace "${APP_NAMESPACE}" \
  --from-literal=database_username="${DATABASE_USERNAME}" \
  --from-literal=database_password="${DATABASE_PASSWORD}" \
  --from-literal=database_root_password="${DATABASE_ROOT_PASSWORD}" \
  --from-literal=database_name="${DATABASE_NAME}" \
  --dry-run=client -o yaml | kubectl apply -f -

log "Installing application (Helm release '${APP_RELEASE}')"
helm upgrade --install "${APP_RELEASE}" "${REPO_ROOT}/helm-charts/emapp" \
  --namespace "${APP_NAMESPACE}" \
  -f "${REPO_ROOT}/helm-charts/emapp/values-dev.yaml" \
  --set app.secret.create=false \
  --set app.config.mysql.databaseName="${DATABASE_NAME}" \
  --set app.config.mysql.databaseUsername="${DATABASE_USERNAME}" \
  --set app.config.mysql.databaseUrl="jdbc:mysql://${MYSQL_RELEASE}:3306/${DATABASE_NAME}?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true" \
  --wait

log "Done. Access the app at http://localhost:30080/actuator/health"
