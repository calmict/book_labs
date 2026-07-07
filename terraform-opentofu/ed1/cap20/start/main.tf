# Chapter 20 — the twins and the lock.
#
# A minimal configuration whose only job is to put a SECRET in the state: a
# random_password. Unencrypted, that secret sits in terraform.tfstate in plain
# text (chapter 11's open problem). The 5% of this chapter — OpenTofu's native
# state encryption — is enabled from OUTSIDE the code, via the TF_ENCRYPTION
# environment variable (see start/encryption.hcl.example and the README).

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

# We deliberately do NOT output the secret itself — the point is that it lives
# in the state file whether we print it or not.
output "note" {
  value = "a 24-char secret now lives in terraform.tfstate (encrypted or not)"
}
