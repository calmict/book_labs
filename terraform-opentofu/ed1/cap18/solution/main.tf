# Chapter 18 solution — the AFTER state, all three refactors applied.
#
# app -> frontend (moved), cache forgotten (removed), the orphan volume
# adopted (import). Applied on top of the BEFORE state, this whole refactor
# is: Plan: 1 to import, 0 to add, 0 to change, 0 to destroy — nothing is
# demolished.

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

# TODO 1, completed: renamed from "app" to "frontend" (the real container name
# stays cap18-app — only the Terraform address changed).
resource "docker_container" "frontend" {
  name  = "cap18-app"
  image = docker_image.web.image_id

  ports {
    internal = 80
    external = 8110
  }
}

# The moved block turns a destroy+create into a state-only rename.
moved {
  from = docker_container.app
  to   = docker_container.frontend
}

# TODO 2, completed: the cache resource is gone from the code; this removed
# block forgets it from the state without destroying the running container.
# (Terraform users write this with an inner lifecycle { destroy = false }.)
removed {
  from = docker_container.cache
}

# TODO 3, completed: adopt the orphan volume created by hand. The id is the
# volume's real name; the resource matches reality, so it imports with 0
# changes.
import {
  to = docker_volume.data
  id = "cap18-data"
}

resource "docker_volume" "data" {
  name = "cap18-data"
}
