# Chapter 19, Part A solution — the drawer: workspaces, TODO 1 completed.
#
# One codebase, one backend, one state per workspace. terraform.workspace
# drives the environment.

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

locals {
  settings = {
    dev  = { external_port = 8120 }
    prod = { external_port = 8121 }
  }

  # TODO 1, completed: the environment is the current workspace; cfg is looked
  # up from the map (falling back to dev for the default workspace).
  env = terraform.workspace
  cfg = lookup(local.settings, terraform.workspace, local.settings["dev"])
}

resource "docker_image" "web" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web" {
  name  = "cap19-${local.env}"
  image = docker_image.web.image_id

  ports {
    internal = 80
    external = local.cfg.external_port
  }
}

output "who" {
  value = "${local.env} on ${local.cfg.external_port}"
}
