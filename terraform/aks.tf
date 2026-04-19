resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  sku_tier     = var.sku_tier
  support_plan = var.support_plan

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  role_based_access_control_enabled = true
  local_account_disabled            = false

  default_node_pool {
    name    = "system"
    vm_size = var.system_node_vm_size

    node_count      = 1
    os_disk_size_gb = var.os_disk_size_gb
    vnet_subnet_id  = azurerm_subnet.aks.id

    type = "VirtualMachineScaleSets"

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
    service_cidr      = "10.40.0.0/16"
    dns_service_ip    = "10.40.0.10"
  }

  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.main.id
    msi_auth_for_monitoring_enabled = true
  }

  tags = local.common_tags
}

resource "azurerm_kubernetes_cluster_node_pool" "workers" {
  name                  = "workers"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.worker_node_vm_size
  os_disk_size_gb       = var.os_disk_size_gb
  mode                  = "User"
  vnet_subnet_id        = azurerm_subnet.aks.id

  auto_scaling_enabled = var.worker_autoscaling_enabled
  node_count           = var.worker_autoscaling_enabled ? null : var.worker_node_count
  min_count            = var.worker_autoscaling_enabled ? var.worker_node_min_count : null
  max_count            = var.worker_autoscaling_enabled ? var.worker_node_max_count : null

  upgrade_settings {
    max_surge = "1"
  }

  tags = local.common_tags
}
