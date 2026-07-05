# Chapter 1 — the snowflake and the herd.
#
# One golden mould, two servers cast from it. You only need to complete the
# TODO at the bottom: HCL syntax is covered in chapters 5 and 6 — here you
# read it guided by the comments, you are not expected to write it yet.

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

# The golden configuration: ONE mould for every server. Fix it here, and
# every server cast from it is fixed. No copying from memory, no drift by
# construction.
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

# TODO: declare the second server, so that drift is impossible by
# construction. It must be identical to server_a except for the filename:
#
#   - resource type:   local_file
#   - resource name:   server_b
#   - filename:        ${path.module}/servers/server-b.conf
#   - content:         the SAME golden mould (local.golden_config)
#   - file_permission: "0644"
#
# Copy the block above and change only what must change.

# The herd tag, printed after every apply.
output "herd_tag" {
  value = random_pet.herd.id
}
