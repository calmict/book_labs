# Chapter 12 — one notebook, with a lock.
#
# A small world whose state starts LOCAL (next to the code, as always —
# for the last time). Phase 1 moves the notebook into the Consul backend
# you switched on in Phase 0; Phase 3 stages the lock collision.

terraform {
  # TODO 1 (Phase 1): the answer to the question «where». Uncomment, then
  # run: tofu init -migrate-state   (and answer yes to the copy question).
  # Note what this block does NOT mention: resources, providers. The
  # backend is pure state logistics.
  #
  # backend "consul" {
  #   address = "127.0.0.1:8500"
  #   scheme  = "http"
  #   path    = "book-labs/cap12"
  # }

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

resource "random_pet" "site" {
  length = 2
}

# TODO 2 (Phase 3): slow work, so you can stage the lock collision — an
# apply that stays busy ~20 seconds while the colleague tries to plan.
# Uncomment (and copy the updated main.tf to the colleague too):
#
# resource "time_sleep" "slow_work" {
#   create_duration = "20s"
# }

output "site_name" {
  value = random_pet.site.id
}
