# Chapter 15 solution — the fleet by name, TODOs completed.
#
# for_each counts by identity (no fragile index); a conditional gates the
# canary; a dynamic block generates the labels from a map.

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

variable "fleet" {
  type    = list(string)
  default = ["alpha", "bravo", "charlie"]
}

variable "canary_enabled" {
  type    = bool
  default = false
}

variable "labels" {
  type = map(string)
  default = {
    team = "platform"
    tier = "web"
  }
}

resource "docker_image" "web" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

# TODO 1, completed: counted BY NAME. toset() turns the list into a set of
# identities; each.key is the name, so the addresses are web["alpha"]...
# Removing one entry now touches only that one.
resource "docker_container" "web" {
  for_each = toset(var.fleet)
  name     = "cap15-${each.key}"
  image    = docker_image.web.image_id

  # TODO 3, completed: one labels block per entry in var.labels.
  dynamic "labels" {
    for_each = var.labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# TODO 2, completed: the canary exists only when enabled — count = 0 means
# the resource is declared but not created.
resource "docker_container" "canary" {
  count = var.canary_enabled ? 1 : 0
  name  = "cap15-canary"
  image = docker_image.web.image_id
}
