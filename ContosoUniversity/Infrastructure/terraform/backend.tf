terraform {
  backend "azurerm" {
    resource_group_name  = "rg-devops"
    storage_account_name = "satfstate98722"
    container_name       = "dotnet-contosouniversity-tfstate"
    key                  = "terraform.tfstate"
  }
}
