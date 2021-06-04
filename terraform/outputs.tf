output "rg_name" {
  value = azurerm_resource_group.cu.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.cu.name
}

output "acr_name" {
  value = azurerm_container_registry.cu.name
}

output "appgw_id" {
  value = azurerm_application_gateway.ag.id
}