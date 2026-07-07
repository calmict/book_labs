# Chapter 13, Phase 0 — the monolith: the building WITHOUT fire doors.
#
# Two teams, one file, one state, one lock. Apply it, then play the
# network team: rename the network (cap13-core-net -> cap13-core-net-v2)
# and read the plan — the fire spreads to the app's container too. Undo,
# then demolish: the rooms get built next door (../network and ../app).

terraform {
  backend "consul" {
    address = "127.0.0.1:8500"
    scheme  = "http"
    path    = "book-labs/cap13/monolith"
  }

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# --- the network team's turf ---
resource "docker_network" "core" {
  name = "cap13-core-net"
}

# --- the app team's turf (same notebook, same fate) ---
resource "docker_image" "app" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "app" {
  name  = "cap13-app"
  image = docker_image.app.image_id

  networks_advanced {
    name = docker_network.core.name
  }
}
