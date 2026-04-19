# Employee Management Web App — Infrastructure

Spring Boot application packaged with a full DevOps toolchain:
**Docker → Kind (dev) → AKS (prod)** via Helm and Terraform, with
SealedSecrets for production credentials and GitHub Actions for CI/CD.

---

## Table of Contents

- [Architecture](#architecture)
- [Repository Layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
  - [Local (Docker Compose)](#local-docker-compose)
  - [Dev Cluster (Kind)](#dev-cluster-kind)
  - [Prod Cluster (AKS)](#prod-cluster-aks)
- [Environments: Dev vs Prod](#environments-dev-vs-prod)
- [Helm Chart](#helm-chart)
- [Secrets: SealedSecrets Workflow](#secrets-sealedsecrets-workflow)
- [Terraform (AKS)](#terraform-aks)
- [CI/CD](#cicd)
- [Troubleshooting](#troubleshooting)

---

## Architecture

```
                       ┌─────────────────────────┐
                       │   GitHub Actions        │
                       │ PR: build+lint+scan     │
                       │ main: push image + tag  │
                       └───────────┬─────────────┘
                                   │
                         ┌─────────┴─────────┐
                         ▼                   ▼
                ┌─────────────────┐ ┌─────────────────┐
                │   Docker Hub    │ │   GHCR (chart)  │
                │ spridoloba/emapp│ │ oci://…/emapp   │
                └────────┬────────┘ └────────┬────────┘
                         │                   │
                         └─────────┬─────────┘
                                   ▼
        ┌──────────────────────────────────────────────┐
        │                  Kubernetes                  │
        │                                              │
        │  ┌────────────┐   ┌────────┐   ┌─────────┐   │
        │  │  Ingress   │──▶│ emapp  │──▶│  MySQL  │   │
        │  │ (cert-mgr) │   │(Helm)  │   │(Bitnami)│   │
        │  └────────────┘   └────────┘   └─────────┘   │
        │         ▲             │                      │
        │         │             ▼                      │
        │   ┌──────────┐  ┌──────────────┐             │
        │   │SealedSec.│  │  HPA / PDB   │             │
        │   │controller│  │NetworkPolicy │             │
        │   └──────────┘  └──────────────┘             │
        └──────────────────────────────────────────────┘
```

**Stack:** Spring Boot 3.3.x (Java 17) · MySQL 8.4 · Helm 3 · Kind ·
AKS · Terraform (`azurerm ~> 4`) · SealedSecrets · cert-manager ·
ingress-nginx · Trivy · kubeconform.

---

## Repository Layout

```
.
├── Dockerfile                 # multi-stage, non-root, layered jars
├── docker-compose.yml         # local dev stack (app + MySQL)
├── .env.example               # template for local secrets
├── pom.xml                    # Spring Boot 3.3 + actuator + layered jars
├── src/                       # Java sources (unchanged)
│
├── helm-charts/emapp/         # Helm chart
│   ├── Chart.yaml
│   ├── values.yaml            # base defaults
│   ├── values-dev.yaml        # Kind overrides
│   ├── values-prod.yaml       # AKS overrides
│   └── templates/             # Deployment, Service, Ingress, HPA, PDB,
│                              # NetworkPolicy, ConfigMap, Secret,
│                              # SealedSecret, ServiceAccount, tests
│
├── k8s/
│   ├── kind/cluster.yaml      # Kind cluster (ingress port mappings)
│   └── bootstrap/             # one-time controllers:
│       ├── install.sh         # ingress-nginx + cert-manager +
│       │                      # sealed-secrets (idempotent)
│       ├── *-values.yaml
│       └── cluster-issuer-*.yaml
│
├── scripts/
│   ├── install-prerequisites.sh
│   ├── dev-setup.sh           # Kind + bootstrap + MySQL + app
│   ├── dev-teardown.sh
│   └── seal-secret.sh         # produce encryptedData for values-prod.yaml
│
├── terraform/                 # AKS cluster (azurerm ~> 4.0)
│   ├── providers.tf / backend.tf / variables.tf
│   ├── main.tf / network.tf / aks.tf / outputs.tf
│   └── README.md
│
└── .github/workflows/
    ├── ci_pr.yml              # build + helm lint + kubeconform +
    │                          # terraform validate + Trivy
    └── ci_main_push.yml       # build + image push + chart push + deploy
```

---

## Prerequisites

Install the tools below (or run `./scripts/install-prerequisites.sh` to verify):

| Tool | Version | Purpose |
|---|---|---|
| Docker | 24+ | Container runtime |
| kubectl | 1.28+ | Kubernetes CLI |
| Helm | 3.14+ | Chart tooling |
| Kind | 0.23+ | Local Kubernetes |
| kubeseal | 0.26+ | Encrypt SealedSecrets |
| Terraform | 1.9+ | AKS provisioning |
| Azure CLI | latest | `az login` before terraform |
| Maven | 3.9+ | Java build (or use Docker) |

---

## Quick Start

### Local (Docker Compose)

```bash
cp .env.example .env          # adjust if needed
docker compose up -d --build
curl http://localhost:8080/actuator/health    # → {"status":"UP"}
docker compose down -v        # reset DB volume
```

Optional Adminer UI on port 8081:

```bash
docker compose --profile tools up -d
```

### Dev Cluster (Kind)

End-to-end on a throwaway local cluster:

```bash
./scripts/install-prerequisites.sh
./scripts/dev-setup.sh        # creates Kind, installs controllers,
                              # deploys MySQL + emapp
kubectl get pods -n emapp
curl http://localhost:30080/actuator/health
./scripts/dev-teardown.sh     # deletes the Kind cluster
```

What `dev-setup.sh` does:
1. `kind create cluster -n emapp --config k8s/kind/cluster.yaml`
2. `k8s/bootstrap/install.sh` → ingress-nginx, cert-manager, sealed-secrets
3. `helm install bitnami/mysql` in the `emapp` namespace
4. Creates `emapp-secret` from `.env`
5. `helm upgrade --install emapp helm-charts/emapp -f values-dev.yaml`

### Prod Cluster (AKS)

1. **Provision AKS** (see [Terraform](#terraform-aks)).
2. **Connect kubectl:**
   ```bash
   az aks get-credentials -g emapp-rg -n emapp-aks --overwrite-existing
   ```
3. **Bootstrap cluster-wide controllers** (once per cluster):
   ```bash
   k8s/bootstrap/install.sh
   ```
4. **Seal production secrets** (see [Secrets](#secrets-sealedsecrets-workflow)):
   ```bash
   export DB_USERNAME=... DB_PASSWORD=... DB_NAME=emapp_prod
   ./scripts/seal-secret.sh >> helm-charts/emapp/values-prod.yaml
   ```
5. **Install Bitnami MySQL:**
   ```bash
   helm upgrade --install mysql bitnami/mysql -n emapp --create-namespace \
     -f helm-charts/sqlvalues.yaml
   ```
6. **Deploy the app:**
   ```bash
   helm upgrade --install emapp helm-charts/emapp \
     -f helm-charts/emapp/values-prod.yaml \
     --set app.image.tag=1.0.0 -n emapp
   ```

---

## Environments: Dev vs Prod

The Helm chart supports both through stacked values files.
**Base defaults live in `values.yaml`; `values-dev.yaml` and `values-prod.yaml`
override what matters per environment.**

| Feature | Dev (Kind) | Prod (AKS) |
|---|---|---|
| Image tag | `latest` | Pinned semver (`1.0.0`) |
| Replicas | 1 | 2 (HPA 2–6) |
| Service | NodePort `:30080` | ClusterIP + Ingress+TLS |
| Ingress | off | `nginx` + cert-manager |
| HPA | off | CPU 70% / mem 80% |
| PDB | off | `minAvailable: 1` |
| NetworkPolicy | off | ingress from ingress-nginx only; egress → MySQL+DNS |
| Secret | Plain `Secret` from `.env` | `SealedSecret` committed to repo |
| Pod anti-affinity | off | preferred by zone |
| MySQL | Bitnami standalone (2 Gi) | Bitnami standalone (10 Gi, resources pinned) |
| Resources | 100m/256Mi → 500m/512Mi | 250m/512Mi → 1000m/1Gi |

Always lint both before committing:

```bash
helm lint helm-charts/emapp/ -f helm-charts/emapp/values-dev.yaml
helm lint helm-charts/emapp/ -f helm-charts/emapp/values-prod.yaml
```

---

## Helm Chart

### Templates

All templates are gated by `.Values.*.enabled` so the same chart renders
differently per environment:

- `deployment.yaml` — `runAsNonRoot`, `readOnlyRootFilesystem`, capabilities
  dropped, HTTP probes on `/actuator/health/{liveness,readiness}`,
  `checksum/config` to roll pods on ConfigMap change.
- `service.yaml` — NodePort in dev, ClusterIP in prod.
- `ingress.yaml` — gated; TLS annotated for cert-manager ClusterIssuer.
- `hpa.yaml` / `pdb.yaml` / `networkpolicy.yaml` — prod only.
- `configmap.yaml` — `SPRING_DATASOURCE_URL`, `SPRING_PROFILES_ACTIVE`,
  `APP_PORT`.
- `secret.yaml` — dev only.
- `sealedsecret.yaml` — prod only, encrypted per-cluster.
- `serviceaccount.yaml` — dedicated SA, `automountServiceAccountToken: false`.
- `tests/test-connection.yaml` — `helm test` hits `/actuator/health`.

### Useful commands

```bash
helm template helm-charts/emapp -f helm-charts/emapp/values-dev.yaml | less
helm test emapp -n emapp
helm rollback emapp -n emapp
```

---

## Secrets: SealedSecrets Workflow

Dev uses a plain `Secret` populated from `.env`. Prod **never** stores
plaintext in git — the workflow:

```
.env ──▶ kubectl create secret --dry-run ──▶ kubeseal ──▶ encryptedData
                                                            │
                                   committed to values-prod.yaml
```

The `sealed-secrets` controller (installed by `k8s/bootstrap/install.sh`)
holds the per-cluster private key and decrypts at admission time into a
regular `Secret`.

```bash
export DB_USERNAME=emapp DB_PASSWORD=changeme DB_NAME=emapp_prod
./scripts/seal-secret.sh
# paste the emitted encryptedData block into values-prod.yaml
# under: app.sealedSecret.encryptedData
```

**Keys to back up:** the SealedSecrets controller's signing key lives in
`kube-system` (or `sealed-secrets` namespace). Losing it means you cannot
decrypt previously-sealed values. Export it periodically:

```bash
kubectl get secret -n sealed-secrets \
  -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o yaml > sealed-secrets-key.backup.yaml
```

---

## Terraform (AKS)

Provisions: resource group, VNet+subnet, Log Analytics, AKS cluster with
OIDC issuer + workload identity, system + autoscaling worker node pools.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in subscription_id
terraform init
terraform plan
terraform apply
```

Remote state is **off by default** (local). To switch to Azure Storage,
uncomment `backend.tf` and follow the bootstrap instructions printed there.

Full walkthrough: [`terraform/README.md`](terraform/README.md).

---

## CI/CD

### Pull Requests — `.github/workflows/ci_pr.yml`

| Job | What it checks |
|---|---|
| `build` | `mvn -B package`, uploads jar |
| `helm_lint` | `helm lint` base/dev/prod + `kubeconform -strict` |
| `terraform_check` | `fmt -check`, `init -backend=false`, `validate` |
| `tests` | Runs the jar against a MySQL service container and hits `/actuator/health` |
| `docker_build` | `docker buildx build` with gha cache + Trivy `fs` + `image` scans (HIGH,CRITICAL, report-only) |

Tighten Trivy by flipping `exit-code: "0"` → `"1"` once the backlog is clean.

### Main branch — `.github/workflows/ci_main_push.yml`

1. Calculates next semver via `mathieudutour/github-tag-action`.
2. Builds and pushes image `spridoloba/emapp:<version>` + `:latest` to Docker Hub.
3. Packages the chart, pushes to `ghcr.io/<owner>/charts/emapp`.
4. Creates git tag + GitHub release.
5. Deploys to AKS using `values-prod.yaml` (with CI-specific overrides:
   LoadBalancer service, plain Secret from CI secrets, Ingress off).

---

## Troubleshooting

**Pods CrashLoopBackOff on Kind**
`docker info | grep -E "CPUs|Memory"` — Kind needs ≥ 4 GB. Increase Docker
Desktop resources.

**Ingress 404 on Kind**
Ingress-nginx must be scheduled on the control-plane node with the
`ingress-ready=true` label (set in `k8s/kind/cluster.yaml`). Verify:

```bash
kubectl -n ingress-nginx get pods -o wide
```

**Prod deploy can't decrypt SealedSecret**
Either the `sealed-secrets` controller isn't installed, or the sealed blob
was encrypted against a different cluster's key. Re-seal against the
current cluster's certificate:

```bash
kubeseal --fetch-cert --controller-namespace sealed-secrets > cert.pem
kubectl create secret generic emapp-secret --dry-run=client -o yaml \
  --from-literal=SPRING_DATASOURCE_PASSWORD=... \
  | kubeseal --cert cert.pem -o yaml
```

**Helm deploy hangs on `--wait`**
Readiness probe failing — check `kubectl describe pod` for the error and
`kubectl logs` for Spring Boot output. Common causes: wrong JDBC URL,
MySQL not yet ready, `readOnlyRootFilesystem` blocking a writable path
not mapped to `emptyDir`.

**Terraform state drift**
If you switched to remote state mid-project, `terraform init -migrate-state`
moves local state into the configured backend. Never delete
`terraform.tfstate` files that haven't been migrated.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for branch conventions, commit
style, and the review checklist.
