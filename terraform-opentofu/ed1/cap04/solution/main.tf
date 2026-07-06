# Chapter 4 solution — the invisible foreman.
#
# The tower, chained: each floor REFERENCES the previous one (implicit
# edges), and the certificate waits for the whole tower through an explicit
# depends_on (no value flows from the floors into it). The apply takes ~15
# seconds — one floor at a time — where the unchained version took ~5.

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

# TODO 1, completed: the reference IS the edge. No order is written anywhere;
# the value flowing from floor_1 into floor_2's triggers is what makes the
# graph sequential.
resource "time_sleep" "floor_2" {
  create_duration = "5s"

  triggers = {
    builds_on = time_sleep.floor_1.id
  }
}

resource "time_sleep" "floor_3" {
  create_duration = "5s"

  triggers = {
    builds_on = time_sleep.floor_2.id
  }
}

# TODO 2, completed: no attribute of the floors appears in the content, so
# no reference exists — the edge is declared by hand. Rule of thumb: a
# reference when a value is truly needed, depends_on only when the
# dependency is real but invisible to the data.
resource "local_file" "certificate" {
  filename = "${path.module}/certificate.txt"
  content  = "occupancy approved"

  depends_on = [time_sleep.floor_3]
}
