# Chapter 22 solution — the configuration the belt delivers (unchanged from
# start: the work of this chapter is the pipeline, not the config).

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "web" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "app" {
  name  = "cap22-app"
  image = docker_image.web.image_id

  ports {
    internal = 80
    external = 8140
  }
}
