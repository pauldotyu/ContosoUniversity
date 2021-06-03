terraform {
  backend "remote" {
    organization = "contosouniversity"

    workspaces {
      name = "contosouniversity"
    }
  }
}