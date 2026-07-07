# Chapter 16 — the workbench: functions, for expressions, tofu console.
#
# Take a badly written list of hosts and work it on the bench until it is a
# clean set that drives real containers. Try every expression in
# tofu console before you commit it.

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

# The raw material: whitespace, mixed case, and one duplicate (Web-01 / web-01).
variable "raw_hosts" {
  type    = list(string)
  default = ["  Web-01 ", "API-02", "web-01", "DB-03 "]
}

locals {
  # TODO 1 (Phase 1): clean each raw host (lower + trimspace) with a list
  # comprehension, then toset() to dedup. Replace the empty placeholder.
  # Try it in tofu console first.
  clean_hosts = toset([])

  # TODO 2 (Phase 2): a map host -> role, where role is the prefix before the
  # dash (split("-", h)[0]). Use a map comprehension. Replace the placeholder.
  host_roles = {}

  # TODO 3 (Phase 3): only the web-tier hosts, with an if filter on the
  # comprehension. Replace the empty placeholder.
  web_hosts = toset([])
}

resource "docker_image" "web" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

# Chapter 15's legacy: the transformed set drives the containers. With the
# placeholder above this creates nothing; once TODO 1 is done, one per host.
resource "docker_container" "host" {
  for_each = local.clean_hosts
  name     = "cap16-${each.key}"
  image    = docker_image.web.image_id
}

# Functions producing a real artifact (not a TODO): jsonencode + sort + tolist
# serialise your three collections into a file.
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
