# Chapter 21 solution — the behaviour tests, TODOs completed.

variables {
  environment = "dev"
}

run "plan_defaults" {
  command = plan

  assert {
    condition     = local.container_name == "cap21-dev"
    error_message = "the container name should derive from the environment"
  }

  # TODO 1, completed: the url output uses the default port.
  assert {
    condition     = output.url == "http://localhost:8130"
    error_message = "the url output should use the default port"
  }
}

# TODO 2, completed: the validation rejects a bad environment. The test passes
# BECAUSE the plan fails, on exactly this variable.
run "rejects_bad_environment" {
  command = plan

  variables {
    environment = "banana"
  }

  expect_failures = [
    var.environment,
  ]
}

run "apply_creates_container" {
  command = apply

  assert {
    condition     = docker_container.web.name == "cap21-dev"
    error_message = "the running container should be named cap21-dev"
  }
}
