# Chapter 19, Part B — the dev room (given, your model for prod).
#
# Its own directory, its own state, its own init. It calls the shared module
# with development settings.

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

module "app" {
  source        = "../modules/webapp"
  environment   = "dev"
  external_port = 8122
}

output "url" {
  value = module.app.url
}
