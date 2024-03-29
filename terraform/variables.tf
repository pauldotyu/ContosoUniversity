variable "deployment_subscription_id" {
  type = string
}

variable "location" {
  type = string
}

variable "username" {
  type        = string
  description = "Azure SQL username"
}

variable "vnet_address_space" {
  type        = list(string)
  description = "Virtual network address space"
}

variable "snet_aks_address_space" {
  type        = list(string)
  description = "AKS subnet address space"
}

variable "snet_agw_address_space" {
  type        = list(string)
  description = "AppGateway subnet address space"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version"
}

variable "default_node_pool_vm_size" {
  type        = string
  description = "Default node pool VM size"
}

variable "cluster_node_pool_vm_size" {
  type        = string
  description = "Cluster node pool VM size"
}

variable "cluster_node_count" {
  type        = number
  description = "Cluster node count"
}

variable "admin_group_object_ids" {
  type        = list(string)
  description = "Azure AD Admin Group Object IDs for RBAC"
}

variable "tags" {
  type = map(any)
}

variable "authorized_ip_addresses" {
  type = list(string)
}