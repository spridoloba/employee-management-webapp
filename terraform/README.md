# Terraform — AKS cluster for emapp

Provisions an AKS cluster with: resource group, VNet + AKS subnet, Log Analytics
workspace (OMS agent), OIDC issuer + workload identity, system + worker node
pools.

## Prerequisites

- Terraform >= 1.5
- Azure CLI logged in (`az login`)
- Azure subscription with quota for the chosen VM SKUs and region

## Quick start

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # then edit values
terraform init
terraform plan
terraform apply
```

Get kubeconfig after apply:

```bash
terraform output -raw kube_config_raw > ~/.kube/config-emapp-aks
export KUBECONFIG=~/.kube/config-emapp-aks
kubectl get nodes
```

Or via az CLI:

```bash
az aks get-credentials \
  --resource-group "$(terraform output -raw resource_group_name)" \
  --name "$(terraform output -raw cluster_name)" \
  --overwrite-existing
```

## Remote state

Local state is the default. To switch to an Azure Storage backend, uncomment
the backend block in `backend.tf` and follow the bootstrap steps printed there.

## Destroying

```bash
terraform destroy
```

Double-check that the release pipeline isn't pointing at the cluster before
destroying it in a shared environment.

## File layout

| File | Purpose |
|---|---|
| `backend.tf`          | Remote state template (commented) |
| `providers.tf`        | Provider + version pins |
| `variables.tf`        | All inputs |
| `main.tf`             | Resource group + Log Analytics |
| `network.tf`          | VNet + AKS subnet |
| `aks.tf`              | AKS cluster + worker node pool |
| `outputs.tf`          | Cluster metadata, kubeconfig |
| `terraform.tfvars.example` | Template for your tfvars |
