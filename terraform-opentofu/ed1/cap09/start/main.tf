# Chapter 9 — arguments, attributes and the art of turning a blind eye.
#
# The resource on the operating table: everything YOU write is an ARGUMENT
# (input); everything the resource exports once alive is an ATTRIBUTE
# (output) — id, IP, dozens of computed values born at apply time.

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "docker" {}

resource "docker_image" "web" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web" {
  # Arguments: the input you impose.
  name  = "cap09-web"
  image = docker_image.web.image_id # <- an ATTRIBUTE of the image, entering

  # TODO 2 (Phase 3): after the night team strikes, add here the missing
  # piece of lifecycle — the blind-eye contract:
  #
  #   lifecycle {
  #     ignore_changes = [restart]
  #   }

  ports {
    internal = 80
    external = 8093
  }
}

# TODO 1 (Phase 1): the dossier — a local_file consuming two OUTPUTS of
# the container. Uncomment and fill the content with two interpolations:
#   - the container's id:  docker_container.web.id
#   - its internal ip:     docker_container.web.network_data[0].ip_address
# Then run tofu plan BEFORE applying, and look for (known after apply).
#
# resource "local_file" "dossier" {
#   filename        = "${path.module}/dossier.txt"
#   content         = <<-EOT
#     container id : ${ ... }
#     internal ip  : ${ ... }
#   EOT
#   file_permission = "0644"
# }

# Outputs: two attributes promised to whoever looks from outside.
output "container_id" {
  value = docker_container.web.id
}

output "container_ip" {
  value = docker_container.web.network_data[0].ip_address
}
