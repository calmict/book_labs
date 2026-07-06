# Chapter 6 solution — the first stone.
#
# The first complete configuration: the terraform block (who translates),
# the provider block (how to talk to it), the resources (what must exist)
# and an output (what to expose). A real web service, switched on from code.

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Empty body = the default local Docker engine (see SETUP.md).
provider "docker" {}

resource "docker_image" "web" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web" {
  name  = "cap06-web"
  image = docker_image.web.image_id

  # A nested block (no equals sign). The published port is contended
  # identity: changing it forces a replacement (Phase 5, chapter 3's echo).
  ports {
    internal = 80
    external = 8087
  }
}

output "url" {
  value = "http://localhost:8087"
}
