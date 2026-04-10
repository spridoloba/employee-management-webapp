locals {
  common_tags = merge(
    {
      Environment = var.environment
      Project     = "employee-management-webapp"
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# ---------------------------------------------------------------------------
# AKS Cluster
#
# sku_tier = "Premium" + support_plan = "AKSLongTermSupport" enables LTS,
# which is required for Kubernetes 1.31+ in this region. LTS provides
# 2 years of support instead of the standard 1 year.
#
# Azure fully manages the control plane (API server, etcd, scheduler).
# The default_node_pool is a dedicated *system* pool (1 node) for kube-system
# add-ons only. Application workloads run on the *workers* pool (2 nodes).
# ---------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  sku_tier     = "Premium"
  support_plan = "AKSLongTermSupport"

  # System node pool — 1 node, kube-system workloads only
  default_node_pool {
    name    = "system"
    vm_size = var.system_node_vm_size

    node_count      = 1
    os_disk_size_gb = var.os_disk_size_gb

    type = "VirtualMachineScaleSets"

    # Prevents application pods from landing on the system node
    only_critical_addons_enabled = true

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Worker Node Pool — 2 nodes, runs all application workloads
# ---------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster_node_pool" "workers" {
  name                  = "workers"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.worker_node_vm_size
  node_count            = var.worker_node_count
  os_disk_size_gb       = var.os_disk_size_gb
  mode                  = "User"

  upgrade_settings {
    max_surge = "1"
  }

  tags = local.common_tags
}
