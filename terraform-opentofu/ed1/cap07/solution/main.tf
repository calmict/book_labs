# Chapter 7 solution — the version register.
#
# Final state after the exercise: the gate open to any modern binary
# (TODO 1) and the pessimistic operator on the provider (TODO 2). The lock
# file — the register — is NOT here: it is born at init, and in a real
# project it would be committed next to this file (in this exercise repo
# it is gitignored so the experiments stay repeatable).

terraform {
  # TODO 1, completed: the gate. It protects the TEAM: a colleague with an
  # ancient binary is stopped at init, before touching anything. OpenTofu
  # was born at 1.6, so this holds for both binaries.
  required_version = ">= 1.6.0"

  required_providers {
    random = {
      source = "hashicorp/random"

      # TODO 2, completed: the pessimistic operator — >= 3.5.0, < 4.0.0.
      # Patches and minors welcome, majors fenced out. The fence says what
      # is ACCEPTABLE; the lock file says what is USED: no ordinary init
      # moves the choice — only init -upgrade does, deliberately.
      version = "~> 3.5"
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
