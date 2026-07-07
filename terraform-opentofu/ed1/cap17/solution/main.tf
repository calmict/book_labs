# Chapter 17 solution — the root, TODOs 2 and 3 completed.
#
# One prefab (./modules/webapp), instantiated once per application with
# for_each, and its output doors aggregated into a single map.

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Configured ONCE here; every module instance inherits this provider.
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

# TODO 2, completed: call the box once per application.
module "webapp" {
  source   = "./modules/webapp"
  for_each = var.apps

  name          = each.key
  environment   = each.value.environment
  external_port = each.value.external_port
}

# TODO 3, completed: read every instance's output door into one map.
output "urls" {
  value = { for k, m in module.webapp : k => m.url }
}
