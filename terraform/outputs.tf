output "kubernetes_version" {
  description = "Kubernetes version deployed on the cluster (auto-selected if not pinned)"
  value       = azurerm_kubernetes_cluster.main.kubernetes_version
}

output "resource_group_name" {
  description = "Name of the resource group containing the cluster"
  value       = azurerm_resource_group.main.name
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "cluster_id" {
  description = "Resource ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "cluster_endpoint" {
  description = "Kubernetes API server URL"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].host
  sensitive   = true
}

output "kube_config_raw" {
  description = "Raw kubeconfig file content (use: terraform output -raw kube_config_raw)"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "client_certificate" {
  description = "Base64-encoded client certificate for cluster authentication"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].client_certificate
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL — used for workload identity federation"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet managed identity — needed to grant ACR pull access"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "node_resource_group" {
  description = "Auto-generated resource group that holds the cluster's VMs and infrastructure"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}
