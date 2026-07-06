# Chapter 11 — the notebook and its secrets.
#
# A small world with a secret: a database password (marked sensitive),
# the nginx image, a container. No writing TODO this time: this chapter's
# work is READING — the notebook (terraform.tfstate), the plans, the
# errors. Follow the README phase by phase.

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "docker" {}

# The secret: sensitive redacts it in outputs and plans — but the VALUE
# must live in the state (Phase 2 shows you where, in plain text).
resource "random_password" "db" {
  length  = 20
  special = true
}

resource "docker_image" "web" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web" {
  name  = "cap11-web"
  image = docker_image.web.image_id
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}
