# Chapter 20 solution — the configuration is the same plain config: the work of
# this chapter is operational (choice of binary, native state encryption via
# TF_ENCRYPTION), not a change to the HCL. See run.sh for the full walk.

terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

resource "random_password" "db" {
  length  = 24
  special = true
}

output "note" {
  value = "a 24-char secret now lives in terraform.tfstate (encrypted or not)"
}
