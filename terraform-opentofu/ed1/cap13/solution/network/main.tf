# Chapter 13 — the network room. Complete: nothing to write here.
#
# Its own notebook (note the backend path), and ONE official door to the
# outside world: the network_name output. Everything else in this state
# is this team's own business — that is the contract.

terraform {
  backend "consul" {
    address = "127.0.0.1:8500"
    scheme  = "http"
    path    = "book-labs/cap13/network"
  }

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_network" "core" {
  name = "cap13-core-net"
}

# The room's official door: what this state EXPOSES. The app room will
# read this — and only this — through terraform_remote_state.
output "network_name" {
  value = docker_network.core.name
}
