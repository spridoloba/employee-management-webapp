#!/usr/bin/env bash
# Verify that the local toolchain needed for the dev flow is installed.
# Prints missing tools and an OS-aware install hint. Does NOT install
# anything automatically — package management is the developer's call.
set -euo pipefail

REQUIRED=(docker kubectl helm kind kubeseal terraform az mvn curl jq wget)

missing=()
for cmd in "${REQUIRED[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing+=("$cmd")
  fi
done

if [[ ${#missing[@]} -eq 0 ]]; then
  echo "All prerequisites are present."
  exit 0
fi

echo "Missing tools: ${missing[*]}"
echo
echo "Installation hints:"
cat <<'EOF'
  macOS (Homebrew):
    brew install docker kubectl helm kind kubeseal terraform azure-cli maven jq

  Linux (apt-get):
    # Docker   — https://docs.docker.com/engine/install/
    # kubectl  — https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
    # helm     — https://helm.sh/docs/intro/install/#from-apt-debianubuntu
    # kind     — go install sigs.k8s.io/kind@latest
    # kubeseal — https://github.com/bitnami-labs/sealed-secrets/releases
    # terraform— https://developer.hashicorp.com/terraform/install
    # az cli   — https://learn.microsoft.com/cli/azure/install-azure-cli

  Arch (pacman):
    sudo pacman -S docker kubectl helm kind terraform azure-cli jq maven
    # kubeseal via AUR or prebuilt release
EOF
exit 1
