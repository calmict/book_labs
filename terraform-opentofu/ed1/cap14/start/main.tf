# Chapter 14 — the three doors: input variables, outputs, locals.
#
# The front door (variables) lets values in; the service door (output)
# shows the outside only what it promises; the internal kitchen (locals)
# has no door onto the world — it derives values and reuses them.

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# The front door: input variables.

# Required: NO default. Whoever uses this config must provide it.
variable "environment" {
  type        = string
  description = "Target environment for this service."

  # TODO 1 (Phase 1): the bouncer. Allow only dev, staging, prod.
  # Uncomment and complete the condition (external_port below is your model).
  #
  # validation {
  #   condition     = contains([ ... ], var.environment)
  #   error_message = "The environment must be one of: dev, staging, prod."
  # }
}

# Optional: a default makes it convenient — but it is still validated.
variable "external_port" {
  type    = number
  default = 8095

  validation {
    condition     = var.external_port > 1024 && var.external_port < 65536
    error_message = "The port must be between 1025 and 65535."
  }
}

# The internal kitchen: locals, derived once and reused.
# TODO 2 (Phase 3): derive the container name from the environment,
# then use local.container_name in the container below.
#
# locals {
#   container_name = "cap14-web-${var.environment}"
# }

resource "docker_image" "web" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web" {
  # TODO 2 (Phase 3): replace this placeholder with local.container_name.
  name  = "cap14-web-PLACEHOLDER"
  image = docker_image.web.image_id

  ports {
    internal = 80
    external = var.external_port
  }
}

# The service door: outputs — the only thing the outside world sees.
# TODO 3 (Phase 4): expose the URL where the service answers. Uncomment
# and complete value with two interpolations (the port and the environment).
#
# output "url" {
#   description = "Where the service answers."
#   value       = "http://localhost:${ ... } (${ ... })"
# }
