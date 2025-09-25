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
  kubernetes_version  = var.kubernetes_version != null ? var.kubernetes_version : data.azurerm_kubernetes_service_versions.current.latest_version
  node_resource_group = "${var.resource_group_name}-nrg"
  default_node_pool {
    name       = var.default_node_pool.name
    vm_size    = var.default_node_pool.vm_size
    vnet_subnet_id = var.default_node_pool.vnet_subnet_id
    temporary_name_for_rotation = substr(lower("temp${var.default_node_pool.name}"), 0, 12)
    orchestrator_version = var.kubernetes_version != null ? var.kubernetes_version : data.azurerm_kubernetes_service_versions.current.latest_version
    auto_scaling_enabled = var.default_node_pool.auto_scaling_enabled
    node_count           = var.default_node_pool.node_count
    max_count            = var.default_node_pool.auto_scaling_enabled ? var.default_node_pool.max_count : null
    min_count            = var.default_node_pool.auto_scaling_enabled ? var.default_node_pool.min_count : null
    os_disk_size_gb      = var.default_node_pool.os_disk_size_gb
    type                 = "VirtualMachineScaleSets"
    node_labels          = local.final_default_node_labels
    tags                 = local.final_default_tags
  }
  # Identity (System Assigned or Service Principal)
  identity {
    type = "SystemAssigned"
  }

  # Network Profile
  network_profile {
    network_plugin = "azure"
    load_balancer_sku = "standard"
  }

}
