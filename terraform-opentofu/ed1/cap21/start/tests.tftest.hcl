# Chapter 21 — the behaviour tests (the top of the pyramid).
#
# Each run block is a case: it fixes variables, runs a command (plan or
# apply), and checks assert blocks. Complete the two TODOs, then: tofu test

variables {
  environment = "dev"
}

run "plan_defaults" {
  command = plan

  # A working assert, as your model: the name derives from the environment.
  assert {
    condition     = local.container_name == "cap21-dev"
    error_message = "the container name should derive from the environment"
  }

  # TODO 1 (Phase 2): make this assert check the url output. It should equal
  # "http://localhost:8130" with the default port. Tighten the placeholder
  # condition (right now it only checks the output is non-empty).
  assert {
    condition     = output.url != ""
    error_message = "the url output should use the default port"
  }
}

# TODO 2 (Phase 2): add a run block that proves the environment validation
# REJECTS a bad value. Use command = plan, set environment = "banana", and
# expect_failures = [var.environment]. Uncomment and complete:
#
# run "rejects_bad_environment" {
#   command = plan
#   variables {
#     environment = "banana"
#   }
#   expect_failures = [
#     var.environment,
#   ]
# }

run "apply_creates_container" {
  command = apply

  assert {
    condition     = docker_container.web.name == "cap21-dev"
    error_message = "the running container should be named cap21-dev"
  }
}
