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

variable "default_node_pool" {
  description = "Configuration for the default AKS node pool."
  type = object({
    name                 = string
    vnet_subnet_id       = string
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
    vm_size              = "standard_b2s"
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