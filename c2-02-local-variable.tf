locals {
  # Define the default tags and labels that every node pool should have.
  default_node_labels = {
    "nodepoolos"        = "linux"
    "default-node-pool" = "true"
  }
  default_tags = {
    "nodepoolos"        = "linux"
    "default-node-pool" = "true"
  }
  

  final_default_node_labels = merge(local.default_node_labels, var.default_node_pool.labels)
  final_default_tags        = merge(local.default_tags, var.default_node_pool.tags)

}