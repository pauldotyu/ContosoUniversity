terraform {
  backend "remote" {
    organization = "pauldotyu"

    workspaces {
      name = "contosouniversity"
    }
  }
}