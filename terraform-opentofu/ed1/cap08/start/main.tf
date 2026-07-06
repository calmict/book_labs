# Chapter 8 — one translator, two sites.
#
# ONE translator (the docker provider binary that init installs), TWO
# configured lines: the default one towards your local engine (Milan) and
# an aliased one towards the second datacenter you built in Phase 0
# (Frankfurt, the dind container answering on tcp 23750).

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# The default line: no alias, local engine. Every resource without a
# provider meta-argument travels on this one.
provider "docker" {}

# TODO 1 (Phase 1): the second line. Write a second provider "docker"
# block with:
#   alias = "frankfurt"
#   host  = "tcp://127.0.0.1:23750"
# Same translator, different telephone: whoever wants this line must ask
# for it by name.

# --- Milan: already written (this is chapter 6) ---

resource "docker_image" "web_milan" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web_milan" {
  name  = "cap08-web-milan"
  image = docker_image.web_milan.image_id

  ports {
    internal = 80
    external = 8091
  }
}

# --- Frankfurt: TODO 2 (Phase 2) ---
#
# Write the twins of the two resources above:
#   - docker_image "web_frankfurt":  same image name, keep_locally true,
#     plus the placement line:  provider = docker.frankfurt
#   - docker_container "web_frankfurt": name cap08-web-frankfurt, image
#     from web_frankfurt, ports internal 80 / external 8092, plus the
#     same placement line.
#
# The provider meta-argument is needed on BOTH: the two engines share
# nothing, not even the image cache — Frankfurt must pull its own copy.
