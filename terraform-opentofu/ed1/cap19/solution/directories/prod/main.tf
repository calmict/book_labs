# Chapter 19, Part B solution — the prod room, TODO 2 completed.

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
  environment   = "prod"
  external_port = 8123
}

output "url" {
  value = module.app.url
}
