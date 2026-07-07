# Chapter 17 — the webapp module: the prefab (a box with doors).
#
# Input doors  = variables (name, environment, external_port)
# Machinery    = resources (docker_image + docker_container)
# Output doors = outputs (url, container_name)
#
# Notice: NO provider "docker" config block here. The module only declares it
# NEEDS the docker provider; its configuration is INHERITED from the root
# that calls it (Phase 0 / 17.4).

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# --- input doors ---
variable "name" {
  type        = string
  description = "Short name of the application (the map key from the root)."
}

variable "environment" {
  type        = string
  description = "Target environment."
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "external_port" {
  type        = number
  description = "Host port the container publishes on."
}

# --- machinery ---
locals {
  container_name = "cap17-${var.name}-${var.environment}"
}

resource "docker_image" "this" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "this" {
  name  = local.container_name
  image = docker_image.this.image_id

  ports {
    internal = 80
    external = var.external_port
  }
}

# --- output doors ---
# TODO 1 (Phase 1): expose the URL the box answers on. Replace the empty
# placeholder with the real value (host, port and environment).
output "url" {
  value = ""
}

output "container_name" {
  value = local.container_name
}
