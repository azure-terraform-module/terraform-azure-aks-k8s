locals {
  default_module_tags = {
    "created-by"        = "terraform"
    "module_name" = "azure-terraform-module/aks_k8s/azure"
  }

  # Check if all node pools have subnet IDs assigned
  default_pool_has_subnet = var.default_node_pool.vnet_subnet_id != null
  custom_pools_have_subnets = length(var.custom_node_pool) == 0 ? true : alltrue([
    for np in var.custom_node_pool : try(np.vnet_subnet_id, null) != null
  ])
  all_pools_have_subnets = local.default_pool_has_subnet && local.custom_pools_have_subnets
  
  # Auto-detect outbound_type: if all pools have subnets, use userAssignedNATGateway, otherwise use the variable
  effective_outbound_type = local.all_pools_have_subnets ? "userAssignedNATGateway" : var.outbound_type
}