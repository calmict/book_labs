# Chapter 19, Part A — the drawer: workspaces.
#
# One codebase, one backend, many states — one per workspace. This config is
# born single-environment; TODO 1 makes it workspace-aware.

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

  # TODO 1 (Part A): make this workspace-aware. Right now env and cfg are
  # hard-coded to dev. Derive env from terraform.workspace, and pick cfg from
  # the settings map with a lookup on terraform.workspace (fall back to dev).
  env = "dev"
  cfg = local.settings["dev"]
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
