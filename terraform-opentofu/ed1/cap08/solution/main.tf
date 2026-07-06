# Chapter 8 solution — one translator, two sites.
#
# ONE translator (the docker provider binary), TWO configured lines: the
# default one (Milan, local engine) and the aliased one (Frankfurt, the
# dind datacenter on tcp 23750). Placement is code: the provider
# meta-argument, resource by resource.

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# The default line: no alias, local engine.
provider "docker" {}

# TODO 1, completed: the second line. Same translator, different
# telephone — and a name, because whoever wants it must ask by name.
# (Plaintext tcp bound to localhost: a lab shortcut. Production would use
# tcp with TLS, or ssh://.)
provider "docker" {
  alias = "frankfurt"
  host  = "tcp://127.0.0.1:23750"
}

# --- Milan (default line) ---

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

# --- Frankfurt (aliased line) — TODO 2, completed ---
# The placement line sits on BOTH resources: the two engines share
# nothing, not even the image cache — Frankfurt pulls its own copy.

resource "docker_image" "web_frankfurt" {
  provider = docker.frankfurt

  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web_frankfurt" {
  provider = docker.frankfurt

  name  = "cap08-web-frankfurt"
  image = docker_image.web_frankfurt.image_id

  ports {
    internal = 80
    external = 8092
  }
}
