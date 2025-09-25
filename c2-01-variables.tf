variable "resource_group_location" {
  description = "The Azure region where the virtual network will be created."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group where the virtual network will be created."
  type        = string
}

variable "cluster_name" {
  description = "(Required) The name of the Managed Kubernetes Cluster to create. Changing this forces a new resource to be created."
  type = string
}

variable "kubernetes_version" {
    description = "Specifies the Kubernetes version for the AKS cluster. Leave this field empty or set to null to use the latest recommended version available at provisioning time. If a specific version is provided (e.g., '1.29'), that version will be used."
    type        = string
    default     = null
}

variable "global_tags" {
  description = "Tags merged into every node pool"
  type        = map(string)
  default     = {}
}

variable "default_node_pool" {
  description = "Configuration for the default AKS node pool."
  type = object({
    name                 = string
    vnet_subnet_id       = optional(string)
    vm_size              = string
    auto_scaling_enabled = bool
    node_count           = number
    max_count            = number
    min_count            = number
    os_disk_size_gb      = number
    node_labels          = map(string)
    tags                 = map(string)
  })

  default = {
    name                 = "systempool"
    vnet_subnet_id       = null
    vm_size              = "Standard_B2s"
    auto_scaling_enabled = true
    node_count           = 2
    max_count            = 3
    min_count            = 1
    os_disk_size_gb      = 30
    node_labels = {
      "nodepool-type" = "system"
    }
    tags = {
      "nodepool-type" = "system"
    }
  }
}

variable "custom_node_pool" {
  description = "List of custom node group configurations"
  type = list(object({
    name                     = string
    vnet_subnet_id       = optional(string)
    auto_scaling_enabled = bool
    node_count           = number
    max_count            = number
    min_count            = number
    os_type              = string
    os_disk_size_gb      = number
    priority             = string
    node_labels          = map(string)
    # Added optionals for real-world pools
    vm_size               = optional(string)
    mode                  = optional(string)                  # "User" or "System"
    node_taints           = optional(list(string))
    tags                  = optional(map(string))
    max_pods              = optional(number)
    # os_disk_type          = optional(string)                  # "Ephemeral" or "Managed"
    eviction_policy       = optional(string)                  # for Spot: "Delete" or "Deallocate"
    spot_max_price        = optional(number)                  # for Spot: -1 or a price in USD/hour
  }))
  default = []
}