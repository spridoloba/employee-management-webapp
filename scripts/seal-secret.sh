#!/usr/bin/env bash
# Seal a Secret for the prod SealedSecret workflow.
#
# Reads DB credentials from .env (or a file passed via --env), builds a plain
# Secret manifest, and encrypts it against the public key of the in-cluster
# sealed-secrets controller. Prints YAML suitable for pasting into
# helm-charts/emapp/values-prod.yaml under app.sealedSecret.encryptedData.
#
# Requires: kubeseal, kubectl (with context pointing at the target cluster).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

NAMESPACE="emapp"
SECRET_NAME="emapp-secret"
CONTROLLER_NS="sealed-secrets"
ENV_FILE="${REPO_ROOT}/.env"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)          ENV_FILE="$2"; shift 2 ;;
    --namespace)    NAMESPACE="$2"; shift 2 ;;
    --secret-name)  SECRET_NAME="$2"; shift 2 ;;
    --controller-namespace) CONTROLLER_NS="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -f "${ENV_FILE}" ]] || { echo "env file not found: ${ENV_FILE}" >&2; exit 1; }
# shellcheck source=/dev/null
set -a; . "${ENV_FILE}"; set +a
: "${DATABASE_NAME:?}"; : "${DATABASE_USERNAME:?}"
: "${DATABASE_PASSWORD:?}"; : "${DATABASE_ROOT_PASSWORD:?}"

tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT

kubectl create secret generic "${SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
  --from-literal=database_username="${DATABASE_USERNAME}" \
  --from-literal=database_password="${DATABASE_PASSWORD}" \
  --from-literal=database_root_password="${DATABASE_ROOT_PASSWORD}" \
  --from-literal=database_name="${DATABASE_NAME}" \
  --dry-run=client -o yaml > "${tmp}"

# Produce a SealedSecret, extract encryptedData block, and print it with
# two-space indent (matches values-prod.yaml nesting under
# app.sealedSecret.encryptedData).
kubeseal --controller-namespace "${CONTROLLER_NS}" --format yaml < "${tmp}" \
  | awk '/^  encryptedData:/{flag=1; next} /^[^ ]/{flag=0} flag' \
  | sed 's/^/  /'
