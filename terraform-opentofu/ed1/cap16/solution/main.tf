# Chapter 16 solution — the workbench, TODOs completed.
#
# The raw list is cleaned and deduped on the bench, reshaped into a map and
# a filtered set, and the clean set drives the containers.

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

variable "raw_hosts" {
  type    = list(string)
  default = ["  Web-01 ", "API-02", "web-01", "DB-03 "]
}

locals {
  # TODO 1, completed: a list comprehension cleans each host (lower +
  # trimspace); toset() dedups Web-01/web-01 into one identity.
  clean_hosts = toset([for h in var.raw_hosts : lower(trimspace(h))])

  # TODO 2, completed: a map comprehension (: becomes =>) maps each host to
  # its role, the prefix before the dash.
  host_roles = { for h in local.clean_hosts : h => split("-", h)[0] }

  # TODO 3, completed: the same comprehension with a trailing if keeps only
  # the web-tier hosts.
  web_hosts = toset([for h in local.clean_hosts : h if split("-", h)[0] == "web"])
}

resource "docker_image" "web" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "host" {
  for_each = local.clean_hosts
  name     = "cap16-${each.key}"
  image    = docker_image.web.image_id
}

resource "local_file" "inventory" {
  filename = "${path.module}/inventory.json"
  content = jsonencode({
    hosts = sort(tolist(local.clean_hosts))
    roles = local.host_roles
    web   = tolist(local.web_hosts)
  })
}

output "host_roles" {
  value = local.host_roles
}

output "web_hosts" {
  value = local.web_hosts
}
