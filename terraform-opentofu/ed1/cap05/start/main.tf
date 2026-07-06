# Chapter 5 — the skyscraper's datasheet.
#
# From this chapter on you WRITE the HCL. Everything in this file is made
# of two things only: BLOCKS (a type, optional quoted labels, a body in
# braces) and ARGUMENTS (name = expression). The detail that tells them
# apart: nested blocks (required_providers inside terraform) carry no
# equals sign.
#
# Fill the placeholders following TODOs 1-5, in order. The file stays
# VALID at every step: run tofu validate as often as you like.

terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

locals {
  # The building's records: the three primitive types. Note that 42 and
  # 191.5 are the same type to HCL: number.
  name      = "Torre Aurora" # string
  floors    = 42             # number (integer)
  height_m  = 191.5          # number (decimal)
  certified = true           # bool

  # TODO 1 — the list of materials. Order matters and duplicates are
  # allowed: the foreman wrote "steel" TWICE — keep it double, it is
  # deliberate. Expected content: steel, glass, steel, concrete.
  materials = []

  # Do not touch this line: a preview of chapter 16 (functions). toset()
  # turns your list into a set — compare the two in Phase 3.
  unique_materials = toset(local.materials)

  # TODO 2 — the map of floor areas: three keys (basement, ground, tower),
  # three numbers (800, 650, 400). Same shape for every value: that is
  # what makes it a map.
  floor_area = {}

  # TODO 3 — the address object: street "Via dei Grafi" (string), number 4
  # (number), historic false (bool). Different types under one roof: that
  # is what makes it an object.
  address = {}

  # TODO 4 — the coordinates tuple: latitude 45.4642, longitude 9.19,
  # province "MI". No field names: position is the meaning.
  coordinates = []

  # TODO 5 — the datasheet itself: replace the placeholder with a heredoc
  # (<<-EOT ... EOT — the dash lets you indent without dirtying the
  # result) full of interpolations, one for every access syntax:
  #
  #   == ${local.name} ==
  #   floors     : ${local.floors}
  #   height     : ${local.height_m} m
  #   certified  : ${local.certified}
  #   street     : ${local.address.street} ${local.address.number}
  #   ground area: ${local.floor_area["ground"]} sqm
  #   latitude   : ${local.coordinates[0]}
  #   materials  : ${join(", ", local.unique_materials)}
  #
  # (join is the second and last chapter-16 preview: it glues a
  # collection's elements into one string.)
  # Complete TODOs 1-4 BEFORE this one: the accesses need real values.
  datasheet = "(datasheet not compiled yet)\n"
}

# A block with two labels (type and name) and a body of arguments.
resource "local_file" "datasheet" {
  filename        = "${path.module}/datasheet.txt"
  content         = local.datasheet
  file_permission = "0644"
}

# Outputs: the apply marks your homework in Phase 3.
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
