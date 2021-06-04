output "acr_name" {
  value = azurerm_container_registry.cu.name
}

output "appgw_id" {
  value = azurerm_application_gateway.ag.id
}