# Chapter 12 solution — one notebook, with a lock.
#
# Final state: the notebook lives in the Consul backend (TODO 1: moved
# there with tofu init -migrate-state), and the model carries the slow
# work used to stage the lock collision (TODO 2). Whoever clones this
# code attaches to the SAME state: chapter 11's incident cannot happen —
# and two simultaneous writes are serialised by the lock.

terraform {
  # TODO 1, completed: pure state logistics — nothing about resources or
  # providers. Changing this block is an init-time affair (the state must
  # be moved), never an apply-time one.
  backend "consul" {
    address = "127.0.0.1:8500"
    scheme  = "http"
    path    = "book-labs/cap12"
  }

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

# TODO 2, completed: ~20 seconds of busy apply, long enough for the
# colleague's plan to hit the lock and read its name tag.
resource "time_sleep" "slow_work" {
  create_duration = "20s"
}

output "site_name" {
  value = random_pet.site.id
}
