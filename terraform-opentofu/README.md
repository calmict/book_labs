# Terraform & OpenTofu — exercises

Practical labs for the Calm ICT **Terraform & OpenTofu** manual.

> Status: scaffolding. The chapter index below is filled in as exercises are
> created from the manual sources.

## Recommended setup

These exercises run locally and for free — no paid cloud account is needed to
complete any of them. See [SETUP.md](SETUP.md) for a reproducible (non-binding)
environment: OpenTofu (or Terraform), plus a local Docker engine for the
exercises that provision real resources.

## One language, two binaries

The manual covers both **OpenTofu** and **Terraform**: the same HCL, an
interchangeable CLI. The solution scripts call tofu, but every command has a
one-to-one terraform equivalent — use whichever you have installed.

## Editions

- **ed1/** — exercises cited by the 1st edition of the manual.

## Chapter index (ed1)

| Chapter | Title | Level | Folder |
|--------:|-------|:-----:|--------|
| 1 | The snowflake and the herd (click-ops, drift, pets vs cattle) | Foundational | [ed1/cap01](ed1/cap01/) |
| 2 | The recipe and the photograph (imperative vs declarative) | Foundational | [ed1/cap02](ed1/cap02/) |
| 3 | Renovate or rebuild (in-place vs replace, the lifecycle block) | Foundational | [ed1/cap03](ed1/cap03/) |
| 4 | The invisible foreman (the dependency graph, DAG, cycles) | Foundational | [ed1/cap04](ed1/cap04/) |
| 5 | The skyscraper's datasheet (HCL anatomy: types, strings, fmt) | Foundational | [ed1/cap05](ed1/cap05/) |
| 6 | The first stone (the CLI, the lifecycle, the saved plan) | Foundational | [ed1/cap06](ed1/cap06/) |
| 7 | The version register (required_version, semver, the lock file) | Foundational | [ed1/cap07](ed1/cap07/) |
| 8 | One translator, two sites (the provider block, aliases, auth) | Foundational | [ed1/cap08](ed1/cap08/) |
| 9 | Arguments, attributes and the art of turning a blind eye (resources) | Intermediate | [ed1/cap09](ed1/cap09/) |
| 10 | The land registry (data sources: reading what you do not own) | Intermediate | [ed1/cap10](ed1/cap10/) |
| 11 | The notebook and its secrets (the state file, three sources of truth) | Intermediate | [ed1/cap11](ed1/cap11/) |
| 12 | One notebook, with a lock (remote backends, migration, state locking) | Intermediate | [ed1/cap12](ed1/cap12/) |
| 13 | The fire doors (state segregation, blast radius, remote_state) | Intermediate | [ed1/cap13](ed1/cap13/) |
| 14 | The three doors (variables, outputs, locals, validation, precedence) | Intermediate | [ed1/cap14](ed1/cap14/) |
| 15 | The fleet: by number or by name (count, for_each, conditionals, dynamic) | Intermediate | [ed1/cap15](ed1/cap15/) |
| 16 | The workbench (functions, for expressions, tofu console) | Intermediate | [ed1/cap16](ed1/cap16/) |
| 17 | The prefab (local modules, for_each reuse, provider inheritance, the Registry) | Intermediate | [ed1/cap17](ed1/cap17/) |
| 18 | The paperwork, not the buildings (moved, removed, import, state commands) | Advanced | [ed1/cap18](ed1/cap18/) |
| 19 | The drawer or the room (environments: workspaces vs separate directories, Terragrunt) | Advanced | [ed1/cap19](ed1/cap19/) |
| 20 | The twins and the lock (OpenTofu vs Terraform: the 95%, the 5%, native state encryption) | Cloud Architect | [ed1/cap20](ed1/cap20/) |

## Pull only this manual

    git clone --filter=blob:none --sparse https://github.com/calmict/book_labs.git
    cd book_labs
    git sparse-checkout set terraform-opentofu/ed1
