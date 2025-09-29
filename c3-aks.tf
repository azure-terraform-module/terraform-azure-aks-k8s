# Documentation Reference: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/kubernetes_service_versions

# Datasource to get Latest Azure AKS latest Version

data "azurerm_kubernetes_service_versions" "current" {
 location = var.resource_group_location
 include_preview = false
}

resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = var.cluster_name
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name
  kubernetes_version  = coalesce(var.kubernetes_version, data.azurerm_kubernetes_service_versions.current.latest_version)
  sku_tier            = var.sku_tier
  node_resource_group = "${var.resource_group_name}-nrg"

  # # Recommended for KEDA auth to Azure via Workload Identity
  # oidc_issuer_enabled      = true
  # workload_identity_enabled = true
  default_node_pool {
    name       = var.default_node_pool.name
    vm_size    = var.default_node_pool.vm_size
    vnet_subnet_id = var.default_node_pool.vnet_subnet_id
    temporary_name_for_rotation = substr(lower("temp${var.default_node_pool.name}"), 0, 12)
    orchestrator_version  = coalesce(var.kubernetes_version, data.azurerm_kubernetes_service_versions.current.latest_version)
    auto_scaling_enabled = var.default_node_pool.auto_scaling_enabled
    node_count           = var.default_node_pool.auto_scaling_enabled ? null : try(var.default_node_pool.node_count, null)
    max_count            = var.default_node_pool.auto_scaling_enabled ? var.default_node_pool.max_count : null
    min_count            = var.default_node_pool.auto_scaling_enabled ? var.default_node_pool.min_count : null
    os_disk_size_gb      = var.default_node_pool.os_disk_size_gb
    type                 = "VirtualMachineScaleSets"
    node_labels          = coalesce(try(var.default_node_pool.node_labels, null), {})
    upgrade_settings {
      max_surge                     = "33%"
      drain_timeout_in_minutes      = 30
      node_soak_duration_in_minutes = 0
    }
    tags                 = merge(local.default_module_tags, coalesce(var.global_tags, {}), coalesce(try(var.default_node_pool.tags, null), {}))
  }
  # Identity (System Assigned or Service Principal)
  identity {
    type = "SystemAssigned"
  }

  # Network Profile
  network_profile {
    network_plugin = "azure" #cilium
    load_balancer_sku = "standard"
  }

  dynamic "workload_autoscaler_profile" {
    for_each = var.application_scaling == null ? [] : [var.application_scaling]

    content {
      keda_enabled                    = workload_autoscaler_profile.value.keda_enabled
      vertical_pod_autoscaler_enabled = workload_autoscaler_profile.value.vertical_pod_autoscaler_enabled
    }
  }
  

  tags = merge(local.default_module_tags, coalesce(var.global_tags, {}))

}

# Collect unique subnet IDs from default and custom node pools
locals {
  aks_subnet_ids = toset([
    for id in concat(
      [var.default_node_pool.vnet_subnet_id],
      [for np in var.custom_node_pool : try(np.vnet_subnet_id, null)]
    ) : id if id != null
  ])
}

# Assign Network Contributor on each subnet to the AKS managed identity
resource "azurerm_role_assignment" "aks_network_contributor" {
  for_each             = local.aks_subnet_ids
  scope                = each.value
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks_cluster.identity[0].principal_id
}