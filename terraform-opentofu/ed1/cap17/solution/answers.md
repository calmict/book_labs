# Chapter 17 — Answers (model solution)

## Installing the box (Phase 2)

    Initializing modules...
    - webapp in modules/webapp

## The module namespace (Phase 3)

    module.webapp["blog"].docker_container.this
    module.webapp["blog"].docker_image.this
    module.webapp["shop"].docker_container.this
    module.webapp["shop"].docker_image.this
    urls = { "blog" = "http://localhost:8101 (dev)", "shop" = "http://localhost:8102 (prod)" }

## One box, many instances (Phase 4)

    # module.webapp["shop"].docker_container.this will be destroyed
    # module.webapp["shop"].docker_image.this will be destroyed
    Plan: 0 to add, 0 to change, 2 to destroy.
    # blog is not in the plan

## The three questions

**a. The box and its doors.**

The module's variables are the input doors: name, environment and
external_port, the values a caller must hand in. The resources are the
machinery: docker_image and docker_container, the actual work, hidden from view.
The outputs are the output doors: url and container_name, the values the module
promises back. The outputs are the interface because they are the only surface a
caller is allowed to depend on — they consume module.webapp["blog"].url, never
the container resource inside. That asymmetry is what makes the box reusable: the
author can rename the container, swap nginx for another image, add resources,
restructure the local — change any of the machinery — and no caller breaks, as
long as url keeps its name and meaning. What the author cannot change without
breaking users is the interface itself: renaming or removing an input variable,
or an output, is a contract change. Machinery is private; doors are public.

**b. Provider inheritance.**

A module describes WHAT to build, not WHERE. So it declares only that it needs
the docker provider (required_providers, for validation and plugin selection)
but not a provider "docker" {} config block — because the "where" (which engine,
which host, which credentials) is a deployment decision, and the module is meant
to be deployed in many places. By default it inherits the root's default docker
provider. To place its resources in an aliased provider instead — chapter 8's
Frankfurt engine — the CALLER passes it explicitly inside the module block:

    providers = {
      docker = docker.frankfurt
    }

The key (docker) is the provider name the module knows internally; the value
(docker.frankfurt) is the configured alias the caller hands it. It is the
caller's choice because the same box may run in Milan for one project and
Frankfurt for another: the author who bakes a fixed provider into the module
destroys exactly the reusability that makes it a module.

**c. The Registry and the bridge.**

A remote module's source points at the Registry (for example
terraform-aws-modules/vpc/aws) and, crucially, pins a version. Pinning matters
for the same reason chapter 7's lock file does: without it, tofu init would pull
the newest matching release each time, and another team's refactor could
silently change what your plan builds — the box would shift under your feet. The
version is the revision you deliberately stand on; you upgrade when you choose,
not when they publish. As for the bridge: wrapping the resources in the module
changed their address, from docker_container.this to
module.webapp["blog"].docker_container.this. Chapter 15 taught that the address
IS the identity in the state — so to Terraform the old resource "disappeared" and
a new one at a new address "appeared", which normally means destroy and rebuild.
Refactoring into a module should not demolish running infrastructure, and that
is exactly the problem Part 5 opens with: chapter 18's moved block tells
Terraform "this is the same resource at a new address", changing the address
without touching reality.
