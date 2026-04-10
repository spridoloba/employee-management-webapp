# Terraform — Azure Kubernetes Service (AKS)

Provisions an AKS cluster for the **employee-management-webapp** with:

| Pool | Nodes | Purpose |
|------|-------|---------|
| `system` (default_node_pool) | 1 | kube-system add-ons only (`CriticalAddonsOnly` taint) |
| `workers` | 2 | Application workloads |

Azure fully manages the Kubernetes control plane (API server, etcd, scheduler).
No additional charge for the control plane in AKS.

---

## Prerequisites

| Tool | Minimum version | Install |
|------|----------------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | 1.5.0 | `brew install terraform` / package manager |
| [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) | 2.55.0 | `brew install azure-cli` |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | matches cluster version | `az aks install-cli` |
| [Helm](https://helm.sh/docs/intro/install/) | 3.x | `brew install helm` |

---

## 1. Authenticate with Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
```

Verify the active subscription:

```bash
az account show --query "{name:name, id:id}" -o table
```

---

## 2. Configure variables

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set at minimum:

```hcl
subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
location        = "East US"     # choose the region closest to you
```

> `terraform.tfvars` is git-ignored. Never commit it.

---

## 3. Deploy the cluster

```bash
# Initialise providers and modules
terraform init

# Preview what will be created (~3 resources)
terraform plan

# Apply — cluster creation takes ~5 minutes
terraform apply
```

Type `yes` when prompted.

---

## 4. Connect kubectl to the cluster

```bash
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw cluster_name) \
  --overwrite-existing

# Verify nodes are Ready
kubectl get nodes -o wide
```

Expected output (3 nodes total):

```
NAME                              STATUS   ROLES    VERSION
aks-system-xxxxxxxxx-vmss000000   Ready    <none>   v1.31.x
aks-workers-xxxxxxxxx-vmss000000  Ready    <none>   v1.31.x
aks-workers-xxxxxxxxx-vmss000001  Ready    <none>   v1.31.x
```

---

## 5. Deploy the application via Helm

### 5a. Create namespaces

```bash
kubectl create namespace emapp
kubectl create namespace mysql
```

### 5b. Deploy MySQL

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm install mysql bitnami/mysql \
  --namespace mysql \
  --values ../helm-charts/sqlvalues.yaml \
  --set auth.rootPassword="<root-password>" \
  --set auth.username="app" \
  --set auth.password="<app-password>" \
  --set auth.database="demo"
```

### 5c. Create the application secret

```bash
kubectl create secret generic emapp-secret \
  --namespace emapp \
  --from-literal=database_name="demo" \
  --from-literal=database_username="app" \
  --from-literal=database_password="<app-password>" \
  --from-literal=database_root_password="<root-password>"
```

### 5d. Deploy the app

```bash
helm install emapp ../helm-charts/emapp \
  --namespace emapp \
  --set app.mysql.databaseUsername="app" \
  --set app.mysql.databaseName="demo" \
  --set app.mysql.databaseUrl="jdbc:mysql://mysql.mysql:3306/demo?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true"
```

### 5e. Expose via LoadBalancer (AKS)

The existing Helm chart uses NodePort. For AKS, patch the service to use a
cloud load balancer instead:

```bash
kubectl patch svc emapp-service -n emapp \
  -p '{"spec": {"type": "LoadBalancer"}}'

# Wait for an external IP to be assigned (~1 minute)
kubectl get svc emapp-service -n emapp --watch
```

Access the application at `http://<EXTERNAL-IP>:8080`.

---

## 6. Destroy the cluster

```bash
terraform destroy
```

> This deletes **all** resources including the resource group and its contents.
> Data stored in PVCs will be lost.

---

## File structure

```
terraform/
├── providers.tf              # Terraform + provider version constraints
├── variables.tf              # All input variables with defaults
├── main.tf                   # Resource group, AKS cluster, worker node pool
├── outputs.tf                # Useful values after apply
├── terraform.tfvars.example  # Copy → terraform.tfvars, fill in values
└── README.md                 # This file
```

---

## Remote state (optional but recommended for teams)

Uncomment the `backend "azurerm"` block in `providers.tf` and create the
storage account first:

```bash
az group create -n tfstate-rg -l eastus
az storage account create -n tfstate$RANDOM -g tfstate-rg --sku Standard_LRS
az storage container create -n tfstate --account-name <storage-account-name>
```

Then update the backend block with the actual storage account name and run
`terraform init` again to migrate state.
