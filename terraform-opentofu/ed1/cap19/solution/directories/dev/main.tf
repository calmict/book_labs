# Chapter 19, Part B solution — the dev room.

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
