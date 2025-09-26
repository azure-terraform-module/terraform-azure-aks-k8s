locals {
  node_pools    = coalesce(var.custom_node_pool, [])
  pools_by_name = { for np in local.node_pools : np.name => np }
}

resource "azurerm_kubernetes_cluster_node_pool" "this" {
  for_each = local.pools_by_name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks_cluster.id
  name                  = each.value.name
  orchestrator_version  = coalesce(var.kubernetes_version, azurerm_kubernetes_cluster.aks_cluster.kubernetes_version)
  
  # OS and sizing
  os_type         = each.value.os_type
  vm_size         = each.value.vm_size
  os_disk_size_gb = each.value.os_disk_size_gb
  # os_disk_type    = try(each.value.os_disk_type, null)

  # Pool mode and networking
  mode           = try(each.value.mode, "User")
  vnet_subnet_id = try(each.value.vnet_subnet_id, null)
  max_pods       = try(each.value.max_pods, null)

  # Autoscaling vs fixed-size
  auto_scaling_enabled = each.value.auto_scaling_enabled
  min_count            = each.value.auto_scaling_enabled ? each.value.min_count : null
  max_count            = each.value.auto_scaling_enabled ? each.value.max_count : null
  node_count           = each.value.auto_scaling_enabled ? null : each.value.node_count

  # Labels and taints
  node_labels = each.value.node_labels
  node_taints = try(each.value.node_taints, null)
  
  # Priority and spot-specific settings
  priority        = each.value.priority
  eviction_policy = lower(each.value.priority) == "spot" ? coalesce(try(each.value.eviction_policy, null), "Delete") : null
  spot_max_price  = lower(each.value.priority) == "spot" ? try(each.value.spot_max_price, -1) : null

  tags = merge(local.default_module_tags, var.global_tags, coalesce(try(each.value.tags, null), {}))
}