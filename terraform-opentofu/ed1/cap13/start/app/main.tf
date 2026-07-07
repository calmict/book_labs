# Chapter 13 — the app room. Its own notebook, its own lock.
#
# Three TODOs: the intercom towards the network room (1), the container
# joining the network through the CONTRACT — the other state's outputs
# (2), and the slow work used for the two-locks proof (3).

terraform {
  backend "consul" {
    address = "127.0.0.1:8500"
    scheme  = "http"
    path    = "book-labs/cap13/app"
  }

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

provider "docker" {}

# TODO 1 (Phase 2): the intercom — a data source reading ANOTHER state.
# Note it exposes outputs only, never the other room's resources.
# Uncomment:
#
# data "terraform_remote_state" "network" {
#   backend = "consul"
#   config = {
#     address = "127.0.0.1:8500"
#     scheme  = "http"
#     path    = "book-labs/cap13/network"
#   }
# }

resource "docker_image" "app" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "app" {
  name  = "cap13-app"
  image = docker_image.app.image_id

  # TODO 2 (Phase 2): join the network through the contract — the other
  # state's OUTPUT, not its resources. Uncomment:
  #
  # networks_advanced {
  #   name = data.terraform_remote_state.network.outputs.network_name
  # }
}

# TODO 3 (Phase 3): the slow work for the two-locks proof — an apply that
# stays busy ~15s while the network room plans in parallel. Uncomment:
#
# resource "time_sleep" "slow_work" {
#   create_duration = "15s"
# }
