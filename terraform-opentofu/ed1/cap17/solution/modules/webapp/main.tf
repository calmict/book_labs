# Chapter 17 solution — the webapp module (the prefab), TODO 1 completed.
#
# Input doors = variables; machinery = resources; output doors = outputs.
# No provider "docker" config block: the module inherits it from the root.

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
# TODO 1, completed: the box's promise — the only thing callers read of it.
output "url" {
  value = "http://localhost:${var.external_port} (${var.environment})"
}

output "container_name" {
  value = local.container_name
}
