# Chapter 3 solution — renovate or rebuild.
#
# Final state after the exercise: version bumped twice (Phase 2 and 3),
# memory renovated in-place (Phase 1), lifecycle governing the replacement.

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
  # Started at 1.25-alpine; bumped to 1.26 (Phase 2), then 1.27 (Phase 3).
  nginx_version = "1.27-alpine"
}

# The image: the mould the container is cast from. Changing its name means a
# DIFFERENT image — a new mould, never a patched one.
# keep_locally: on destroy, leave the downloaded images on your machine
# (spares the re-pull if you redo the exercise; remove them with docker rmi).
resource "docker_image" "web" {
  name         = "nginx:${local.nginx_version}"
  keep_locally = true
}

# The container. The NAME CONTAINS THE VERSION: two generations never share
# identity — that is what makes create_before_destroy possible below.
resource "docker_container" "web" {
  name  = "cap03-web-${replace(local.nginx_version, ".", "-")}"
  image = docker_image.web.image_id

  # Renovated in-place in Phase 1 (the plan said: will be updated in-place).
  memory = 256

  lifecycle {
    # TODO 1, completed: the new container is built BEFORE the old one is
    # demolished (+/- in the plan, "create replacement and then destroy").
    # Possible only because the two never contend the same name.
    create_before_destroy = true

    # TODO 2, shown here switched OFF: with the catch on, tofu destroy AND
    # any version bump fail with "Instance cannot be destroyed" (a replace
    # is a destroy plus a create). Cleanup requires removing it — you
    # switch the catch off deliberately, in code.
    # prevent_destroy = true
  }
}
