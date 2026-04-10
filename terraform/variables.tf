variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  sensitive   = true
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "emapp-rg"
}

variable "location" {
  description = "Azure region for all resources (e.g. 'East US', 'West Europe')"
  type        = string
  default     = "East US"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "emapp-aks"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster. Must be an LTS-eligible version (1.27, 1.30, 1.31, ...). Run 'az aks get-versions -l <region>' to see options."
  type        = string
  default     = "1.31"
}

variable "system_node_vm_size" {
  description = "VM size for the system node pool (runs kube-system workloads)"
  type        = string
  default     = "Standard_DC2s_v3"
}

variable "worker_node_vm_size" {
  description = "VM size for the worker node pool (runs application workloads)"
  type        = string
  default     = "Standard_DC2s_v3"
}

variable "worker_node_count" {
  description = "Number of worker nodes in the worker node pool"
  type        = number
  default     = 1
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB for each node"
  type        = number
  default     = 50
}

variable "environment" {
  description = "Environment name applied as a tag to all resources"
  type        = string
  default     = "production"
}

variable "tags" {
  description = "Additional tags to merge into all resources"
  type        = map(string)
  default     = {}
}
