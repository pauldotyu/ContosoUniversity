# this file is to be used when running locally or outside of terraform cloud
location                  = "westus3"
vnet_address_space        = ["10.240.0.0/16"]
snet_aks_address_space    = ["10.240.0.0/24"]
snet_agw_address_space    = ["10.240.1.0/24"]
kubernetes_version        = "1.22.6"
default_node_pool_vm_size = "Standard_B2ms"
cluster_node_pool_vm_size = "Standard_DS2_v2"
cluster_node_count        = 1
admin_group_object_ids    = ["70ea9e17-0efa-4b84-a3c6-c7644068cd51"]
tags = {
  environment = "dev"
  project     = "contosouniversity"
}