# Chapter 15 — the fleet: by number or by name.
#
# count multiplies by number (fragile position); for_each by name (stable
# identity); a conditional makes a resource exist or not; a dynamic block
# multiplies nested blocks inside a resource.

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

# The fleet, counted BY NUMBER. Apply it (Phase 0), feel the fragile-index
# trap (Phase 1) — then TODO 1 asks you to re-count it BY NAME.
#
# TODO 1 (Phase 2): replace count/count.index with for_each over toset(var.fleet)
# and each.key, so the addresses become web["alpha"], web["bravo"]...
resource "docker_container" "web" {
  count = length(var.fleet)
  name  = "cap15-${var.fleet[count.index]}"
  image = docker_image.web.image_id

  # TODO 3 (Phase 4): after TODO 1, generate one labels block per entry in
  # var.labels with a dynamic block. Uncomment and complete.
  #
  # dynamic "labels" {
  #   for_each = var.labels
  #   content {
  #     label = ...
  #     value = ...
  #   }
  # }
}

# TODO 2 (Phase 3): the canary — a container that exists only when enabled.
# Uncomment and complete count with a conditional expression (? 1 : 0).
#
# resource "docker_container" "canary" {
#   count = ...
#   name  = "cap15-canary"
#   image = docker_image.web.image_id
# }
