# Chapter 19, Part B — the shared module (chapter 17's prefab).
#
# Both dev/ and prod/ call this same box with their own settings; each keeps
# its own state in its own directory.

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

variable "environment" {
  type = string
}

variable "external_port" {
  type = number
}

resource "docker_image" "web" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web" {
  name  = "cap19dir-${var.environment}"
  image = docker_image.web.image_id

  ports {
    internal = 80
    external = var.external_port
  }
}

output "url" {
  value = "http://localhost:${var.external_port} (${var.environment})"
}
