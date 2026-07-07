# Chapter 17 — the root: it drops the prefab (the ./modules/webapp box) into
# the city, once per application, and reads back their output doors.

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# The root configures the provider ONCE; the module inherits this config.
provider "docker" {}

variable "apps" {
  type = map(object({
    environment   = string
    external_port = number
  }))
  default = {
    blog = { environment = "dev", external_port = 8101 }
    shop = { environment = "prod", external_port = 8102 }
  }
}

# TODO 2 (Phase 2): call the box, once per application. Uncomment and complete.
# source points at the local module path; for_each instantiates it per map
# entry; the three inputs feed the module's input doors.
#
# module "webapp" {
#   source   = "./modules/webapp"
#   for_each = var.apps
#
#   name          = each.key
#   environment   = each.value.environment
#   external_port = each.value.external_port
# }

# TODO 3 (Phase 3): gather every instance's url into one map. Replace the
# empty placeholder with a for expression over module.webapp.
output "urls" {
  value = {}
}
