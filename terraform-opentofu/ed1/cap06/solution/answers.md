# Chapter 6 — Answers (model solution)

## init, under the lens (Phase 2)

    64M  .terraform/providers/registry.opentofu.org/kreuzwerker/docker/3.9.0/linux_amd64/terraform-provider-docker_v3.9.0
    # (your version and size may differ slightly — the order of magnitude
    # is the point: tens of MB for ONE translator)

    # the second init took about 1 second

## The saved plan (Phase 3)

    Saved the plan to: first.plan

    # did tofu apply first.plan ask for confirmation? NO

## The three everyday commands (Phase 4)

    docker_container.web
    docker_image.web

## After the destroy (Phase 6)

    .  ..  .terraform  .terraform.lock.hcl  first.plan  main.tf
    # the infrastructure is gone; the studio is intact

## The three questions

**a. Two binaries, one language — and two installations.**

I installed one thing only: the tofu binary (a few tens of MB, somewhere
in my PATH). init installed the translator: the kreuzwerker/docker
provider binary, about 64 MB, inside this folder's .terraform directory —
per working directory, at the version the lock file pinned. The split
makes sense because the core's job is universal (parse HCL, build the
graph, diff model against state) while the world's APIs are endless: no
binary could embed a translator for every cloud ever. So the core stays
small and the translators arrive on demand, only the ones this project
declares. With terraform instead of tofu, nothing in the exercise would
change: same HCL, same commands, same providers downloaded from a
registry — two binaries, one language.

**b. The saved plan: a contract that asks no questions.**

first.plan is the serialized diff the plan computed: every action, every
value, frozen into a file. The interactive apply asks for confirmation
because it has just computed a NEW plan and a human must accept it; apply
first.plan asks nothing because the acceptance already happened — the
file IS the approved decision, and apply's only job is to execute it
exactly, no recomputation, no improvisation. That exactness is the whole
value when review and approval sit between plan and execution: what the
reviewer read is byte-for-byte what will run, and if reality drifted in
the meantime the apply fails loudly instead of silently doing something
nobody reviewed. This is why pipelines (chapter 22) are built on
plan -out, review, apply-the-file.

**c. The three everyday questions, and the destroy asymmetry.**

state list answers "what am I managing?" — the inventory of resources
under contract. show answers "what does the reality I manage look like?" —
every attribute, including the dozens of defaults the provider filled in
that I never wrote. output answers "what did I promise to expose?" — the
few values declared as the configuration's public face. Other people's
containers do not appear because the state is not a photograph of the
machine: it is the register of what THIS configuration created — anything
else is simply not its business (which is also what makes it safe to run
on a shared host). destroy removed the infrastructure — container and
image bindings, state entries — and left the studio: main.tf, .terraform
with its translators, the lock file. Exactly right: the product of the
code must be disposable at will precisely because the code that can
rebuild it is not.
