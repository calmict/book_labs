# Chapter 18 — the paperwork, not the buildings.
#
# This is the BEFORE state: two managed containers, app and cache. You will
# refactor it into the AFTER without demolishing anything real:
#   TODO 1 (moved)   — rename app -> frontend safely;
#   TODO 2 (removed) — stop managing cache without destroying it;
#   TODO 3 (import)  — adopt the orphan volume you make by hand in Phase 0.

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "web" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

# TODO 1 (Phase 1): rename this resource's LABEL from "app" to "frontend"
# (leave name = "cap18-app" untouched — only the Terraform address changes),
# then add a moved block so the rename does not destroy and recreate:
#
#   moved {
#     from = docker_container.app
#     to   = docker_container.frontend
#   }
resource "docker_container" "app" {
  name  = "cap18-app"
  image = docker_image.web.image_id

  ports {
    internal = 80
    external = 8110
  }
}

# TODO 2 (Phase 2): the cache moves to another team. DELETE this resource
# block and replace it with a removed block, so Terraform forgets it from the
# state WITHOUT stopping the container:
#
#   removed {
#     from = docker_container.cache
#   }
resource "docker_container" "cache" {
  name  = "cap18-cache"
  image = docker_image.web.image_id
}

# TODO 3 (Phase 3): adopt the orphan volume cap18-data (created by hand in
# Phase 0) with an import block plus the resource that describes it:
#
#   import {
#     to = docker_volume.data
#     id = "cap18-data"
#   }
#
#   resource "docker_volume" "data" {
#     name = "cap18-data"
#   }
