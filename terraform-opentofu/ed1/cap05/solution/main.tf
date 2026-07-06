# Chapter 5 solution — the skyscraper's datasheet.
#
# Every data type of the language, in one card: primitives for the records,
# list (order + duplicates) vs set (neither), map (homogeneous) vs object
# (mixed), tuple (positional), and a heredoc full of interpolations.

terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

locals {
  # The three primitive types. 42 and 191.5 are the same type: number.
  name      = "Torre Aurora" # string
  floors    = 42             # number (integer)
  height_m  = 191.5          # number (decimal)
  certified = true           # bool

  # TODO 1, completed — list: order matters, duplicates allowed. The double
  # "steel" is deliberate: watch what the set below does to it.
  materials = ["steel", "glass", "steel", "concrete"]

  # Chapter-16 preview: toset() turns the list into a set — no duplicates,
  # no order (the output shows it alphabetically and labels it toset).
  unique_materials = toset(local.materials)

  # TODO 2, completed — map: same shape for every value.
  floor_area = {
    basement = 800
    ground   = 650
    tower    = 400
  }

  # TODO 3, completed — object: different types under one roof.
  address = {
    street   = "Via dei Grafi"
    number   = 4
    historic = false
  }

  # TODO 4, completed — tuple: no names, position is the meaning.
  coordinates = [45.4642, 9.19, "MI"]

  # TODO 5, completed — the heredoc: the dash in <<-EOT strips the leading
  # indentation, and every access syntax appears once.
  datasheet = <<-EOT
    == ${local.name} ==
    floors     : ${local.floors}
    height     : ${local.height_m} m
    certified  : ${local.certified}
    street     : ${local.address.street} ${local.address.number}
    ground area: ${local.floor_area["ground"]} sqm
    latitude   : ${local.coordinates[0]}
    materials  : ${join(", ", local.unique_materials)}
  EOT
}

# A block with two labels (type and name) and a body of arguments.
resource "local_file" "datasheet" {
  filename        = "${path.module}/datasheet.txt"
  content         = local.datasheet
  file_permission = "0644"
}

output "materials" {
  value = local.materials
}

output "unique_materials" {
  value = local.unique_materials
}

output "floor_area" {
  value = local.floor_area
}

output "address" {
  value = local.address
}

output "coordinates" {
  value = local.coordinates
}
