provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

data "azurerm_client_config" "current" {}

data "azurerm_log_analytics_workspace" "cu" {
  name                = "lawcontososecopsdiqg"
  resource_group_name = "rg-secops"
}

resource "random_string" "cu" {
  keepers = {
    "storage" = jsonencode(var.tags)
  }
  length    = 4
  min_lower = 4
  special   = false
}


resource "random_password" "cu" {
  length           = 16
  special          = true
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  override_special = "_%@"
}

resource "azurerm_resource_group" "cu" {
  name     = "rg-aks"
  location = "westus2"
  tags     = merge(var.tags, { "creationSource" = "terraform" })
}

resource "azurerm_storage_account" "cu" {
  name                     = "sacu${random_string.cu.result}"
  resource_group_name      = azurerm_resource_group.cu.name
  location                 = azurerm_resource_group.cu.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = merge(var.tags, { "creationSource" = "terraform" })
}

resource "azurerm_mssql_server" "cu" {
  name                         = "sqlcu${random_string.cu.result}"
  resource_group_name          = azurerm_resource_group.cu.name
  location                     = azurerm_resource_group.cu.location
  version                      = "12.0"
  administrator_login          = "azadmin"
  administrator_login_password = random_password.cu.result
  tags                         = merge(var.tags, { "creationSource" = "terraform" })
}

# This is used to enable the firewall
resource "azurerm_mssql_firewall_rule" "cu_fw_rule_0" {
  name             = "azure"
  server_id        = azurerm_mssql_server.cu.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_firewall_rule" "cu_fw_rule_1" {
  name             = "ClientIP"
  server_id        = azurerm_mssql_server.cu.id
  start_ip_address = "99.33.64.127"
  end_ip_address   = "99.33.64.127"
}

resource "azurerm_mssql_firewall_rule" "cu_fw_rule_2" {
  name             = "VPNClientIP"
  server_id        = azurerm_mssql_server.cu.id
  start_ip_address = "167.220.26.104"
  end_ip_address   = "167.220.26.104"
}

resource "azurerm_mssql_database" "cu" {
  name           = "CU"
  server_id      = azurerm_mssql_server.cu.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  read_scale     = false
  sku_name       = "S0"
  zone_redundant = false
  tags           = merge(var.tags, { "creationSource" = "terraform" })
}

resource "azurerm_mssql_server_extended_auditing_policy" "cu" {
  server_id                               = azurerm_mssql_server.cu.id
  storage_endpoint                        = azurerm_storage_account.cu.primary_blob_endpoint
  storage_account_access_key              = azurerm_storage_account.cu.primary_access_key
  storage_account_access_key_is_secondary = false
  retention_in_days                       = 6
}

# Create virtual network so that we can use Azure CNI network profile - this is required for the Key Vault integration
resource "azurerm_virtual_network" "cu" {
  name                = "vn-cu"
  location            = azurerm_resource_group.cu.location
  resource_group_name = azurerm_resource_group.cu.name
  address_space       = ["10.240.0.0/16"]
  tags                = merge(var.tags, { "creationSource" = "terraform" })
}

# Create subnet
resource "azurerm_subnet" "cu" {
  name                 = "ComputeSubnet"
  resource_group_name  = azurerm_resource_group.cu.name
  virtual_network_name = azurerm_virtual_network.cu.name
  address_prefixes     = ["10.240.0.0/24"]
}

resource "azurerm_subnet" "ag" {
  name                 = "AppGatewaySubnet"
  resource_group_name  = azurerm_resource_group.cu.name
  virtual_network_name = azurerm_virtual_network.cu.name
  address_prefixes     = ["10.240.1.0/24"]
}

################################
# AGIC
################################


# user assigned managed identity for application gateway
# resource "azurerm_user_assigned_identity" "ag" {
#   resource_group_name = azurerm_resource_group.cu.name
#   location            = azurerm_resource_group.cu.location

#   name = "agcu${random_string.cu.result}"
# }

# Grant application gateway get access policy on the key vault
# resource "azurerm_key_vault_access_policy" "ag" {
#   key_vault_id = azurerm_key_vault.cu.id
#   tenant_id    = data.azurerm_client_config.current.tenant_id
#   object_id    = azurerm_user_assigned_identity.ag.principal_id

#   certificate_permissions = [
#     "Get",
#     "List",
#   ]

#   secret_permissions = [
#     "Get",
#     "List",
#   ]

#   depends_on = [
#     azurerm_key_vault_access_policy.kv_current
#   ]
# }

# application gateway
resource "azurerm_public_ip" "ag" {
  name                = "agcu${random_string.cu.result}-ip"
  location            = azurerm_resource_group.cu.location
  resource_group_name = azurerm_resource_group.cu.name
  domain_name_label   = "agcu${random_string.cu.result}"
  sku                 = "Standard"
  allocation_method   = "Static"
  zones               = []
  timeouts {

  }
}

resource "azurerm_application_gateway" "ag" {
  name                = "agcu${random_string.cu.result}"
  resource_group_name = azurerm_resource_group.cu.name
  location            = azurerm_resource_group.cu.location

  backend_address_pool {
    name = "appGatewayBackendPool"
  }

  backend_http_settings {
    name                  = "appGatewayBackendHttpSettings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
    connection_draining {
      drain_timeout_sec = 1
      enabled           = false
    }
  }

  frontend_ip_configuration {
    name                 = "appGatewayFrontendIP"
    public_ip_address_id = azurerm_public_ip.ag.id
  }

  frontend_port {
    name = "appGatewayFrontendPort"
    port = 80
  }

  gateway_ip_configuration {
    name      = "appGatewayFrontendIP"
    subnet_id = azurerm_subnet.ag.id
  }

  http_listener {
    name                           = "appGatewayHttpListener"
    frontend_port_name             = "appGatewayFrontendPort"
    frontend_ip_configuration_name = "appGatewayFrontendIP"
    protocol                       = "Http"
  }

  # identity {
  #   identity_ids = [
  #     azurerm_user_assigned_identity.ag.id
  #   ]
  #   type = "UserAssigned"
  # }

  request_routing_rule {
    name                       = "rule1"
    rule_type                  = "Basic"
    http_listener_name         = "appGatewayHttpListener"
    backend_address_pool_name  = "appGatewayBackendPool"
    backend_http_settings_name = "appGatewayBackendHttpSettings"
  }

  sku {
    capacity = 2
    name     = "WAF_v2"
    tier     = "WAF_v2"
  }

  depends_on = [
    azurerm_key_vault.cu
  ]
}

################################
# AKS
################################


resource "azurerm_kubernetes_cluster" "cu" {
  name                = "aks-cu"
  kubernetes_version  = "1.19.7" # az aks get-versions -l westus2 
  location            = azurerm_resource_group.cu.location
  resource_group_name = azurerm_resource_group.cu.name
  dns_prefix          = "contosouniversity${random_string.cu.result}"
  tags                = merge(var.tags, { "creationSource" = "terraform" })

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_B2ms"
    vnet_subnet_id = azurerm_subnet.cu.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    load_balancer_sku  = "Standard"
    service_cidr       = "10.2.0.0/24"
    dns_service_ip     = "10.2.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
  }

  addon_profile {
    aci_connector_linux {
      enabled = false
    }

    azure_policy {
      enabled = false
    }

    http_application_routing {
      enabled = false
    }

    ingress_application_gateway {
      enabled    = false
      #gateway_id = azurerm_application_gateway.ag.id # this does not work - when you create an ingress, nothing gets configured on the app gateway
      #subnet_id = azurerm_subnet.ag.id               # this does work
    }

    kube_dashboard {
      enabled = false
    }

    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = data.azurerm_log_analytics_workspace.cu.id
    }
  }

  role_based_access_control {
    enabled = true
    azure_active_directory {
      managed                = true
      tenant_id              = data.azurerm_client_config.current.tenant_id
      admin_group_object_ids = ["70ea9e17-0efa-4b84-a3c6-c7644068cd51"]
    }
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "cu" {
  name                  = "internal"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.cu.id
  vm_size               = "Standard_DS2_v2"
  node_count            = 1
  vnet_subnet_id        = azurerm_subnet.cu.id
  tags                  = var.tags
}

resource "azurerm_container_registry" "cu" {
  name                = "acrcu${random_string.cu.result}"
  resource_group_name = azurerm_resource_group.cu.name
  location            = azurerm_resource_group.cu.location
  sku                 = "Standard"
  admin_enabled       = true
  tags                = merge(var.tags, { "creationSource" = "terraform" })
}

resource "azurerm_role_assignment" "role_acrpull" {
  scope                            = azurerm_container_registry.cu.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.cu.kubelet_identity.0.object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "cu_role" {
  scope                = azurerm_resource_group.cu.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.cu.identity.0.principal_id
}

# Create a key vault
resource "azurerm_key_vault" "cu" {
  name                            = "kvcu${random_string.cu.result}"
  location                        = azurerm_resource_group.cu.location
  resource_group_name             = azurerm_resource_group.cu.name
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days      = 90
  purge_protection_enabled        = false
  sku_name                        = "standard"
  tags                            = merge(var.tags, { "creationSource" = "terraform" })
  #enable_rbac_authorization       = true
}

# Grant the current login context full access to the key vault
resource "azurerm_key_vault_access_policy" "kv_current" {
  key_vault_id = azurerm_key_vault.cu.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  certificate_permissions = [
    "backup",
    "create",
    "delete",
    "deleteissuers",
    "get",
    "getissuers",
    "import",
    "list",
    "listissuers",
    "managecontacts",
    "manageissuers",
    "purge",
    "recover",
    "restore",
    "setissuers",
    "update"
  ]
  key_permissions = [
    "backup",
    "create",
    "decrypt",
    "delete",
    "encrypt",
    "get",
    "import",
    "list",
    "purge",
    "recover",
    "restore",
    "sign",
    "unwrapKey",
    "update",
    "verify",
    "wrapKey"
  ]
  secret_permissions = [
    "backup",
    "delete",
    "get",
    "list",
    "purge",
    "recover",
    "restore",
    "set"
  ]
  storage_permissions = [
    "backup",
    "delete",
    "deletesas",
    "get",
    "getsas",
    "list",
    "listsas",
    "purge",
    "recover",
    "regeneratekey",
    "restore",
    "set",
    "setsas",
    "update"
  ]

  depends_on = [
    azurerm_key_vault.cu
  ]
}

# Grant AKS cluster get access policy on the key vault
resource "azurerm_key_vault_access_policy" "aks_system" {
  key_vault_id            = azurerm_key_vault.cu.id
  tenant_id               = azurerm_kubernetes_cluster.cu.identity[0].tenant_id
  object_id               = azurerm_kubernetes_cluster.cu.identity[0].principal_id
  certificate_permissions = ["get"]
  secret_permissions      = ["get"]
  key_permissions         = ["get"]

  depends_on = [
    azurerm_key_vault_access_policy.kv_current
  ]
}

# Grant AKS kublet get access policy on the key vault
resource "azurerm_key_vault_access_policy" "aks_kublet" {
  key_vault_id            = azurerm_key_vault.cu.id
  tenant_id               = azurerm_kubernetes_cluster.cu.identity[0].tenant_id
  object_id               = azurerm_kubernetes_cluster.cu.kubelet_identity[0].object_id
  certificate_permissions = ["get"]
  secret_permissions      = ["get"]
  key_permissions         = ["get"]

  depends_on = [
    azurerm_key_vault_access_policy.kv_current
  ]
}

# Save secrets to Key vault
# resource "azurerm_key_vault_secret" "url" {
#   name         = "url"
#   value        = "jdbc:postgresql://${azurerm_postgresql_server.server.fqdn}:5432/grouper"
#   key_vault_id = azurerm_key_vault.cu.id

#   depends_on = [
#     azurerm_key_vault_access_policy.kv_current
#   ]
# }

# resource "azurerm_key_vault_secret" "username" {
#   name         = "username"
#   value        = format("%s@%s", var.psql_login, azurerm_postgresql_server.server.name)
#   key_vault_id = azurerm_key_vault.cu.id

#   depends_on = [
#     azurerm_key_vault_access_policy.kv_current
#   ]
# }

resource "azurerm_key_vault_secret" "password" {
  name         = "mssql-password"
  value        = random_password.cu.result
  key_vault_id = azurerm_key_vault.cu.id
  tags         = merge(var.tags, { "creationSource" = "terraform" })

  depends_on = [
    azurerm_key_vault_access_policy.kv_current
  ]
}

resource "azurerm_key_vault_secret" "connstring" {
  name         = "connectionstring"
  value        = "Server=tcp:${azurerm_mssql_server.cu.fully_qualified_domain_name},1433;Initial Catalog=CU;Persist Security Info=False;User ID=azadmin;Password=${random_password.cu.result};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.cu.id
  tags         = merge(var.tags, { "creationSource" = "terraform" })

  depends_on = [
    azurerm_key_vault_access_policy.kv_current
  ]
}

# Grant AKS kubelet role-based access control for the Secret Store CSI driver
resource "azurerm_role_assignment" "aks_mio" {
  scope                = azurerm_resource_group.cu.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_kubernetes_cluster.cu.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "aks_vmc" {
  scope                = azurerm_resource_group.cu.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_kubernetes_cluster.cu.kubelet_identity[0].object_id
}

