# Chapter 19, Part B — the prod room (TODO 2).
#
# Its own directory, its own state. Complete the module call on the model of
# dev/main.tf, but with production settings (port 8123).

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# TODO 2 (Part B): call the shared module with prod settings. Uncomment and
# complete on the model of dev/main.tf.
#
# module "app" {
#   source        = "../modules/webapp"
#   environment   = "prod"
#   external_port = 8123
# }

# TODO 2 (cont.): expose the module's url. Replace the empty placeholder once
# the module block above is in place.
output "url" {
  value = ""
}
