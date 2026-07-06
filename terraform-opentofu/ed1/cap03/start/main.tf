# Chapter 3 — renovate or rebuild.
#
# A living server this time: a Docker container running nginx. You will
# change its memory (renovation: in-place) and its image version
# (reconstruction: replace), reading in the plan which road the provider
# chose BEFORE applying. Then you will govern the replacement with the
# lifecycle block (the two TODOs below).

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Talks to your local Docker engine (see SETUP.md).
provider "docker" {}

locals {
  # Phase 2 asks you to bump this to 1.26-alpine, Phase 3 to 1.27-alpine.
  nginx_version = "1.25-alpine"
}

# The image: the mould the container is cast from. Changing its name means a
# DIFFERENT image — a new mould, never a patched one.
# keep_locally: on destroy, leave the downloaded images on your machine
# (spares the re-pull if you redo the exercise; remove them with docker rmi).
resource "docker_image" "web" {
  name         = "nginx:${local.nginx_version}"
  keep_locally = true
}

# The container. Note that the NAME CONTAINS THE VERSION: it looks cosmetic,
# it becomes decisive in Phase 3 — two generations never share identity.
resource "docker_container" "web" {
  name  = "cap03-web-${replace(local.nginx_version, ".", "-")}"
  image = docker_image.web.image_id

  # Phase 1 asks you to bring this to 256 — and to read the plan first.
  memory = 128

  # TODO 1 (Phase 3): add here a lifecycle block with
  # create_before_destroy = true, then bump the version above and read the
  # plan: the replacement order flips.
  #
  # TODO 2 (Phase 4): inside the same lifecycle block add
  # prevent_destroy = true, then try tofu destroy — and then try bumping
  # the version too, asking only for the plan.
}
