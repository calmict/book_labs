# Chapter 1 solution — the snowflake and the herd.
#
# One golden mould, two servers cast from it: drift is impossible by
# construction, because there is nothing to copy from memory.

terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# The herd tag: a random name for this generation of servers. Destroy and
# re-apply, and a NEW tag appears — cattle, not pets.
resource "random_pet" "herd" {
  length = 2
}

# The golden configuration: ONE mould for every server.
locals {
  golden_config = <<-EOT
    hostname   = web-${random_pet.herd.id}
    packages   = nginx, openssl
    port       = 8080
    debug_mode = off
  EOT
}

# The first server, cast from the mould.
resource "local_file" "server_a" {
  filename        = "${path.module}/servers/server-a.conf"
  content         = local.golden_config
  file_permission = "0644"
}

# The second server: same mould, only the filename changes. This is the TODO
# from start/main.tf, completed.
resource "local_file" "server_b" {
  filename        = "${path.module}/servers/server-b.conf"
  content         = local.golden_config
  file_permission = "0644"
}

# The herd tag, printed after every apply.
output "herd_tag" {
  value = random_pet.herd.id
}
