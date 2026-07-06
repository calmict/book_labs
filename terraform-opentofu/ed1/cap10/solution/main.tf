# Chapter 10 solution — the land registry.
#
# Final state: the platform's network READ (never owned), the container
# leaning on it, and block B showing the deferred read side by side.

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

# TODO 1, completed: the data block queries the existing network and
# exports its attributes. It exists, independent of this run -> the read
# happens DURING the plan, and everything downstream is already resolved.
data "docker_network" "platform" {
  name = "cap10-platform-net"
}

resource "local_file" "netcard" {
  filename        = "${path.module}/netcard.txt"
  content         = <<-EOT
    network id : ${data.docker_network.platform.id}
    driver     : ${data.docker_network.platform.driver}
    scope      : ${data.docker_network.platform.scope}
  EOT
  file_permission = "0644"
}

resource "docker_image" "web" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web" {
  name  = "cap10-web"
  image = docker_image.web.image_id

  # TODO 2, completed: building on ground we do not own. The edge starts
  # from a data block: first read, then build.
  networks_advanced {
    name = data.docker_network.platform.name
  }
}

# --- Block B: the deferred case. ---
# This network is born only at apply, so the data's read slips to apply
# and the freshcard's content shows (known after apply) in the plan.

resource "docker_network" "ours" {
  name = "cap10-ours-net"
}

data "docker_network" "fresh" {
  name = docker_network.ours.name
}

resource "local_file" "freshcard" {
  filename        = "${path.module}/freshcard.txt"
  content         = "fresh network id : ${data.docker_network.fresh.id}\n"
  file_permission = "0644"
}
