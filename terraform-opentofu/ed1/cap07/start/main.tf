# Chapter 7 — the version register.
#
# The specification book of the project: which core binary is admitted
# (required_version), which translators and at which versions
# (required_providers). This file is complete but BROKEN BY DESIGN at the
# gate: Phase 0 asks you to run tofu init and read the refusal.

terraform {
  # TODO 1 (Phase 0): this gate demands a binary that no longer exists —
  # init refuses, and that refusal is the lesson. Then open the gate to
  # any modern binary:
  #
  #   required_version = ">= 1.6.0"
  #
  required_version = "< 1.0.0"

  required_providers {
    random = {
      source = "hashicorp/random"

      # TODO 2 (Phase 2): after living with the exact pin (Phase 1),
      # replace it with the pessimistic operator:
      #
      #   version = "~> 3.5"
      #
      # meaning >= 3.5.0 and < 4.0.0 — patches and minors welcome, majors
      # (where semver authorises breakage) fenced out. Then re-run init
      # and read WHO wins between the widened fence and the lock file.
      version = "3.5.1"
    }
  }
}

# The site's mascot: an old acquaintance from chapter 1. It exists so the
# configuration has something to apply across all the version experiments.
resource "random_pet" "mascot" {
  length = 2
}

output "mascot" {
  value = random_pet.mascot.id
}
