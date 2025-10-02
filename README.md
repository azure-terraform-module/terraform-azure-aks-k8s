## terraform-azure-aks-k8s

Production-ready Terraform module to provision Azure Kubernetes Service (AKS) clusters with a default system pool and optional custom user pools.

### What this module does
- Creates an AKS cluster (system-assigned identity) with `sku_tier` control-plane tier
- Provisions the default node pool and any number of custom node pools
- Supports Spot priority pools, taints, labels, `mode` (default "User")
- Sets Kubernetes version explicitly or uses the latest recommended version if omitted
- Assigns Network Contributor to the cluster managed identity on all referenced subnets (default and custom pools)

### Prerequisites
- Terraform >= 1.9 and AzureRM provider ~> 4.0 (configure the provider in your root module)
- Existing Resource Group and Subnet(s) for the node pools
- Permissions to create role assignments on the target subnets

## Quickstart
```hcl
terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "aks" {
  source = "../terraform-azure-aks-k8s" # adjust path or use your VCS source

  resource_group_name     = "rg-demo"
  resource_group_location = "eastus"
  cluster_name            = "demo-aks"

  # Control-plane tier: Free | Standard | Premium
  sku_tier = "Standard" # Standard includes Uptime SLA

  # Pin a version or set null to use latest recommended
  kubernetes_version = null

  default_node_pool = {
    name                 = "systempool"
    vnet_subnet_id       = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<subnet>"
    vm_size              = "Standard_D4as_v5"
    auto_scaling_enabled = true
    node_count           = 2
    min_count            = 1
    max_count            = 3
    os_disk_size_gb      = 64
    node_labels          = { "nodepool-type" = "system" }
    tags                 = { "nodepool-type" = "system" }
    # upgrade_settings omitted -> defaults to max_surge="33%", drain_timeout=30, node_soak_duration=0
  }

  custom_node_pool = [
    {
      name                 = "userpool1"
      vnet_subnet_id       = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<subnet>"
      vm_size              = "Standard_D4as_v5"         # required for custom pools
      os_type              = "Linux"
      os_disk_size_gb      = 128
      priority             = "Regular"                   # or "Spot"
      auto_scaling_enabled = true
      min_count            = 1
      max_count            = 5
      node_count           = 0                           # ignored when autoscaling is true
      mode                 = "User"                      # default is "User"
      node_labels          = { workload = "general" }
      tags                 = { workload = "general" }
    }
  ]

  global_tags = {
    environment = "dev"
    owner       = "platform-team"
  }
}
```

Apply:
```bash
terraform init
terraform plan
terraform apply
```

## Inputs (high level)
- `resource_group_name` (string): Target resource group. Required.
- `resource_group_location` (string): Azure region. Required.
- `cluster_name` (string): AKS cluster name. Required.
- `kubernetes_version` (string|null): Version to deploy; when null, uses latest recommended.
- `sku_tier` (string): `Free | Standard | Premium`. Default: `Standard`.
- `global_tags` (map(string)): Merged into node pool tags. Default: `{}`.
- `default_node_pool` (object): Default/system pool settings.
  - Required: `name`, `vm_size`, `auto_scaling_enabled`, `min_count`, `max_count`, `os_disk_size_gb`.
  - Optional: `vnet_subnet_id`, `node_count` (used only if autoscaling disabled), `node_labels`, `tags`, `upgrade_settings`.
    - `upgrade_settings` defaults to `max_surge="33%"`, `drain_timeout_in_minutes=30`, `node_soak_duration_in_minutes=0`.
- `custom_node_pool` (list(object)): Zero or more user/system pools.
  - Required: `name`, `os_type`, `os_disk_size_gb`, `priority`, `auto_scaling_enabled`, `min_count`, `max_count`.
  - Optional with defaults/notes:
    - `node_count` (number): Only when autoscaling disabled; otherwise ignored.
    - `node_labels` (map(string)): Defaults to `{}` if omitted.
    - `vm_size` (string): Required in practice; must be set for each custom pool.
    - `vnet_subnet_id` (string): Optional; when set, role assignment is created.
    - `mode` (string): `User | System`. Default: `User` (validated).
    - `node_taints` (list(string)), `tags` (map(string)), `max_pods` (number).
    - `eviction_policy` (string, Spot only), `spot_max_price` (number, Spot only).
    - `upgrade_settings` (object): Optional. Defaults to `max_surge="33%"`, `drain_timeout_in_minutes=30`, `node_soak_duration_in_minutes=0` for non-Spot pools.

## Behavior and notes
- Versioning: If `kubernetes_version` is null, the module uses the latest recommended version via the provider data source.
- Role assignments: The module assigns the Network Contributor role to the cluster managed identity on every non-null, unique subnet referenced by the default and custom pools.
  - Ensure the caller has permission to create role assignments at the subnet scope.
- Networking: Uses Azure CNI and `standard` load balancer SKU by default.
- Defaults: `custom_node_pool.mode` defaults to "User" and is validated to "User" | "System".
  - Default node pool always uses `upgrade_settings` defaults unless overridden (`max_surge="33%"`, `drain_timeout_in_minutes=30`, `node_soak_duration_in_minutes=0`).
- Control plane tier: `sku_tier` accepts `Free | Standard | Premium` (Standard includes Uptime SLA).

## Example: add a Spot pool
```hcl
custom_node_pool = [
  {
    name                 = "spotpool"
    vnet_subnet_id       = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<subnet>"
    vm_size              = "Standard_D4as_v5"
    os_type              = "Linux"
    os_disk_size_gb      = 128
    priority             = "Spot"
    auto_scaling_enabled = true
    min_count            = 1
    max_count            = 10
    node_count           = 0
    eviction_policy      = "Delete"
    spot_max_price       = -1
    node_labels          = { workload = "batch" }
    node_taints          = ["preemptible=true:NoSchedule"]
    tags                 = { workload = "batch" }
  }
]
```

## Known limitations / roadmap
- The module currently fixes network plugin to Azure CNI and LB SKU to Standard.
- Consider adding private cluster, AAD/RBAC, OIDC/Workload Identity, Azure Policy, diagnostics, and maintenance windows for a complete production posture.

## Reference
- AKS resource (`azurerm_kubernetes_cluster`) and `sku_tier`: [Terraform Registry](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster)
