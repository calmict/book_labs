# Chapter 9 solution — arguments, attributes and the art of turning a
# blind eye.
#
# Final state: the dossier consumes the container's computed attributes
# (TODO 1), and the lifecycle carries the blind-eye contract on restart
# (TODO 2) — the night team's knob, tolerated by contract.

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

  # TODO 2, completed: the blind-eye contract. The restart policy belongs
  # to the operations team: their hand changes no longer show up as drift.
  # Every entry here is a knob the model abdicates — forever and silently.
  lifecycle {
    ignore_changes = [restart]
  }

  ports {
    internal = 80
    external = 8093
  }
}

# TODO 1, completed: the dossier — two OUTPUTS of the container consumed
# by another resource. In the first plan its content is (known after
# apply): the declared unknown, born in the container and propagated here
# along the reference edge.
resource "local_file" "dossier" {
  filename        = "${path.module}/dossier.txt"
  content         = <<-EOT
    container id : ${docker_container.web.id}
    internal ip  : ${docker_container.web.network_data[0].ip_address}
  EOT
  file_permission = "0644"
}

# Outputs: two attributes promised to whoever looks from outside.
output "container_id" {
  value = docker_container.web.id
}

output "container_ip" {
  value = docker_container.web.network_data[0].ip_address
}
