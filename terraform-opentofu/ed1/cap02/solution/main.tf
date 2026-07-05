# Chapter 2 solution — the photograph: the same fleet as provision.sh, but
# described as a RESULT. No steps anywhere: the tool computes them at every
# apply by comparing reality with this model.

terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

locals {
  # The list of servers: the single source the whole model derives from.
  servers = ["server-1", "server-2", "server-3"]

  # The shared part of every config: one mould, as in chapter 1.
  fleet_config = <<-EOT
    packages   = nginx, openssl
    port       = 8080
    debug_mode = off
  EOT
}

# The first server, cast from the mould.
resource "local_file" "server_1" {
  filename        = "${path.module}/fleet/server-1.conf"
  content         = "hostname   = server-1\n${local.fleet_config}"
  file_permission = "0644"
}

# The second server: same mould, different hostname and filename.
resource "local_file" "server_2" {
  filename        = "${path.module}/fleet/server-2.conf"
  content         = "hostname   = server-2\n${local.fleet_config}"
  file_permission = "0644"
}

# The third server: the TODO from start/main.tf, completed.
resource "local_file" "server_3" {
  filename        = "${path.module}/fleet/server-3.conf"
  content         = "hostname   = server-3\n${local.fleet_config}"
  file_permission = "0644"
}

# The inventory is DERIVED from the model: the servers list writes it itself.
# Nobody can forget to register a server, because there is no second place
# to keep in sync.
resource "local_file" "inventory" {
  filename        = "${path.module}/fleet/inventory.txt"
  content         = "${join("\n", local.servers)}\n"
  file_permission = "0644"
}

output "fleet_size" {
  value = length(local.servers)
}
