# Chapter 10 — the land registry.
#
# The platform team owns a network (you created it by hand in Phase 0:
# cap10-platform-net). Your model must never create, modify or destroy
# it — only READ it, with the first data block of your career.

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

# TODO 1 (Phase 1): the data block — same grammar as a resource, opposite
# trade: it QUERIES what exists and exports its attributes. Uncomment and
# complete both blocks (the data and its registry card), then run
# tofu plan BEFORE applying: the read happens DURING the plan, and the
# netcard content arrives already resolved — no (known after apply).
#
# data "docker_network" "platform" {
#   name = "..." # the network the platform team created in Phase 0
# }
#
# resource "local_file" "netcard" {
#   filename        = "${path.module}/netcard.txt"
#   content         = <<-EOT
#     network id : ${data.docker_network.platform.id}
#     driver     : ${data.docker_network.platform.driver}
#     scope      : ${data.docker_network.platform.scope}
#   EOT
#   file_permission = "0644"
# }

resource "docker_image" "web" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web" {
  name  = "cap10-web"
  image = docker_image.web.image_id

  # TODO 2 (Phase 2): attach the container to the platform's network —
  # building on ground you do not own. Uncomment:
  #
  # networks_advanced {
  #   name = data.docker_network.platform.name
  # }
}

# --- Block B (Phase 3), already written: the deferred case. ---
# A network of OURS, and a data reading it: but this network is born only
# at apply, so the read slips to apply and the freshcard's content shows
# (known after apply) — chapter 9's declared unknown, back again.

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
