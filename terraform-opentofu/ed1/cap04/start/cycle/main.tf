# Chapter 4, Phase 5 — the forbidden cycle. BROKEN BY DESIGN: do not fix it.
#
# The chicken is born from the egg, the egg is laid by the chicken: each
# resource references the other, so each edge waits for the other. A graph
# with a cycle admits no execution order at all — nobody can start first.
#
# Run tofu init and then tofu validate here, and read the error carefully:
# it arrives BEFORE anything touches reality, because the graph is built
# from the code alone.

terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

resource "local_file" "chicken" {
  filename = "${path.module}/chicken.txt"
  content  = "born from: ${local_file.egg.id}"
}

resource "local_file" "egg" {
  filename = "${path.module}/egg.txt"
  content  = "laid by: ${local_file.chicken.id}"
}
