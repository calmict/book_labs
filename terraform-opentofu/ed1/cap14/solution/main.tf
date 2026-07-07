# Chapter 14 solution — the three doors, TODOs completed.
#
# Front door (variables) in, service door (output) out, and the internal
# kitchen (locals) deriving the name in between.

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

variable "environment" {
  type        = string
  description = "Target environment for this service."

  # TODO 1, completed: the bouncer checks the ticket before the graph.
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "The environment must be one of: dev, staging, prod."
  }
}

variable "external_port" {
  type    = number
  default = 8095

  validation {
    condition     = var.external_port > 1024 && var.external_port < 65536
    error_message = "The port must be between 1025 and 65535."
  }
}

# TODO 2, completed: the internal kitchen. Not an input (nobody passes it),
# not an output (nobody reads it) — a derived value, computed once.
locals {
  container_name = "cap14-web-${var.environment}"
}

resource "docker_image" "web" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web" {
  name  = local.container_name
  image = docker_image.web.image_id

  ports {
    internal = 80
    external = var.external_port
  }
}

# TODO 3, completed: the service door — the only thing the outside sees.
output "url" {
  description = "Where the service answers."
  value       = "http://localhost:${var.external_port} (${var.environment})"
}
