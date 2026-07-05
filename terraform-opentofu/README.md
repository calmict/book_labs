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
| _exercises are listed here as they are created_ | | | |

## Pull only this manual

    git clone --filter=blob:none --sparse https://github.com/calmict/book_labs.git
    cd book_labs
    git sparse-checkout set terraform-opentofu/ed1
