# Chapter 11 solution — the notebook and its secrets.
#
# Identical to start/ (this is a reading chapter): a secret, an image, a
# container. The lessons live in the notebook, not in the code:
#   - terraform.tfstate binds docker_container.web to the real container
#     id — the mapping neither code nor reality contains (11.1/11.3);
#   - random_password.db.result sits IN PLAIN TEXT in the state, while
#     sensitive redacts outputs and plans (11.4): never commit the state,
#     restrict and encrypt it (backends: ch. 12; native encryption: ch. 20);
#   - plan/apply -refresh-only sync the MEMORY alone after out-of-band
#     changes (11.2: refresh aligns memory<->reality, plan compares
#     code<->memory, apply bends reality to code);
#   - a colleague with the same code but his own empty state plans a full
#     rebuild and crashes into the shared reality (11.5): separate state
#     does not scale past one person — chapter 12.

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
