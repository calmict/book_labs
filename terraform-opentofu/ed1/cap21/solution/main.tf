# Chapter 21 solution — the configuration under inspection (unchanged from
# start: the work of this chapter is the test suite, not the config).

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
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "external_port" {
  type    = number
  default = 8130
}

locals {
  container_name = "cap21-${var.environment}"
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

output "container_name" {
  value = local.container_name
}

output "url" {
  value = "http://localhost:${var.external_port}"
}
