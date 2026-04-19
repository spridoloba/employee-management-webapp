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
  description = "Kubernetes version for the AKS cluster. Run 'az aks get-versions -l <region>' for options."
  type        = string
  default     = "1.31"
}

variable "sku_tier" {
  description = "AKS SKU tier: Free (no SLA, dev/learning), Standard (financial SLA), Premium (LTS)"
  type        = string
  default     = "Free"
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be one of: Free, Standard, Premium."
  }
}

variable "support_plan" {
  description = "AKS support plan: KubernetesOfficial (default) or AKSLongTermSupport (requires Premium tier)"
  type        = string
  default     = "KubernetesOfficial"
}

variable "system_node_vm_size" {
  description = "VM size for the system node pool (runs kube-system workloads)"
  type        = string
  default     = "Standard_B2s"
}

variable "worker_node_vm_size" {
  description = "VM size for the worker node pool (runs application workloads)"
  type        = string
  default     = "Standard_B2s"
}

variable "worker_node_count" {
  description = "Fixed node count when autoscaling is disabled"
  type        = number
  default     = 1
}

variable "worker_autoscaling_enabled" {
  description = "Enable cluster autoscaler on the worker node pool"
  type        = bool
  default     = true
}

variable "worker_node_min_count" {
  description = "Autoscaler min size for the worker node pool"
  type        = number
  default     = 1
}

variable "worker_node_max_count" {
  description = "Autoscaler max size for the worker node pool"
  type        = number
  default     = 3
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

variable "vnet_address_space" {
  description = "CIDR range for the VNet"
  type        = string
  default     = "10.30.0.0/16"
}

variable "aks_subnet_prefix" {
  description = "CIDR range for the AKS subnet"
  type        = string
  default     = "10.30.1.0/24"
}
