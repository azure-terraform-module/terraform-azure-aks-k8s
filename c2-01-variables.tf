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
    description = "Specifies the Kubernetes version for the AKS cluster. Leave this field empty or set to null to use the latest recommended version available at provisioning time. If a specific version is provided (e.g., '1.29'), that version will be used. Please use `az aks get-versions` command to get the supported version list in this region "
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
    node_count           = optional(number)
    max_count            = number
    min_count            = number
    os_disk_size_gb      = number
    node_labels          = optional(map(string))
    tags                 = optional(map(string))
    zones                = optional(list(string))
    upgrade_settings     = optional(object({
      drain_timeout_in_minutes      = number
      node_soak_duration_in_minutes = number
      max_surge                     = string
    }))
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
    upgrade_settings = {
      max_surge                     = "33%"
      drain_timeout_in_minutes      = 30
      node_soak_duration_in_minutes = 0
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
    node_count           = optional(number)
    max_count            = number
    min_count            = number
    os_type              = string
    os_disk_size_gb      = number
    priority             = optional(string, "Regular") # Spot
    node_labels          = optional(map(string))
    # Added optionals for real-world pools
    vm_size               = optional(string)
    mode                  = optional(string, "User")           # "User" or "System"
    node_taints           = optional(list(string))
    tags                  = optional(map(string))
    max_pods              = optional(number)
    # os_disk_type          = optional(string)                  # "Ephemeral" or "Managed"
    eviction_policy       = optional(string)                  # for Spot: "Delete" or "Deallocate"
    spot_max_price        = optional(number)                  # for Spot: -1 or a price in USD/hour
    zones                 = optional(list(string))
    upgrade_settings      = object({
      drain_timeout_in_minutes      = optional(number, 30)
      node_soak_duration_in_minutes = optional(number, 0)
      max_surge                     = optional(string, "33%")
    })
  }))
  default = []

  validation {
    condition     = alltrue([for np in var.custom_node_pool : contains(["User", "System"], try(np.mode, "User"))])
    error_message = "custom_node_pool.mode must be 'User' or 'System'."
  }
}

variable "sku_tier" {
  description = "The SKU Tier for the AKS control plane. Possible values: Free, Standard (Uptime SLA), Premium. Defaults to Free in provider; module default is Standard."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be one of 'Free', 'Standard', or 'Premium'."
  }
}

variable "application_scaling" {
  type = object({
    keda_enabled                    = optional(bool, false)
    vertical_pod_autoscaler_enabled = optional(bool, false)
  })
  default     = null
  description = <<-EOT
    `keda_enabled` - (Optional) Specifies whether KEDA Autoscaler can be used for workloads.
    `vertical_pod_autoscaler_enabled` - (Optional) Specifies whether Vertical Pod Autoscaler should be enabled.
EOT
}