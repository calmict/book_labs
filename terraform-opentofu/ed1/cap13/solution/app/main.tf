# Chapter 13 solution — the app room, TODOs completed.
#
# Its own notebook, its own lock. It reaches the network room only
# through the intercom: terraform_remote_state, reading the other state's
# OUTPUTS — the contract between teams.

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

# TODO 1, completed: the intercom. It exposes outputs only — the network
# team's resources stay its own business.
data "terraform_remote_state" "network" {
  backend = "consul"
  config = {
    address = "127.0.0.1:8500"
    scheme  = "http"
    path    = "book-labs/cap13/network"
  }
}

resource "docker_image" "app" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "app" {
  name  = "cap13-app"
  image = docker_image.app.image_id

  # TODO 2, completed: joined through the contract — the OUTPUT, not the
  # other room's resources.
  networks_advanced {
    name = data.terraform_remote_state.network.outputs.network_name
  }
}

# TODO 3, completed: the slow work for the two-locks proof.
resource "time_sleep" "slow_work" {
  create_duration = "15s"
}
