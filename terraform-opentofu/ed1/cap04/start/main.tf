# Chapter 4 — the invisible foreman.
#
# Three floors, 5 seconds of construction each (time_sleep: the "work" is
# sleeping, which makes the site easy to time with a stopwatch). Note that
# NO floor mentions any other: the model does not know they are a tower.
# Phase 0 asks you to apply this exactly as it is, watching the clock.

terraform {
  required_providers {
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

resource "time_sleep" "floor_1" {
  create_duration = "5s"
}

# TODO 1 (Phase 1): tell the model what physics already knows — each floor
# rests on the previous one. You will not write an order: you will add to
# floor_2 a triggers map whose value REFERENCES floor_1,
#
#   triggers = {
#     builds_on = time_sleep.floor_1.id
#   }
#
# and the same on floor_3, referencing floor_2. Wherever a value flows from
# one resource to another, there the graph has an edge.
resource "time_sleep" "floor_2" {
  create_duration = "5s"
}

resource "time_sleep" "floor_3" {
  create_duration = "5s"
}

# TODO 2 (Phase 2): the certificate of occupancy — born only when the tower
# is finished. Its content uses NO attribute of the floors: no value flows,
# so no reference, so no edge. This is the rare case for an EXPLICIT edge.
# Uncomment and fill the depends_on with the resource that must exist first:
#
# resource "local_file" "certificate" {
#   filename = "${path.module}/certificate.txt"
#   content  = "occupancy approved"
#
#   depends_on = [] # which resource must the certificate wait for?
# }
