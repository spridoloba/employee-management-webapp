#!/usr/bin/env bash
# Tear down the local Kind cluster. No prompts.
set -euo pipefail

CLUSTER_NAME="emapp"

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  printf '\033[1;34m[dev-teardown]\033[0m deleting Kind cluster %s\n' "${CLUSTER_NAME}"
  kind delete cluster --name "${CLUSTER_NAME}"
else
  printf '\033[1;34m[dev-teardown]\033[0m no Kind cluster named %s — nothing to do\n' "${CLUSTER_NAME}"
fi
