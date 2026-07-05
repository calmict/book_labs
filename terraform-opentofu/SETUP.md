# Terraform & OpenTofu — environment setup (non-binding)

These exercises run entirely on your machine, for free. No paid cloud account
is required to complete any of them. This guide is a **suggestion**: any recent
OpenTofu or Terraform will do.

## Option A — OpenTofu (recommended)

    # install: https://opentofu.org/docs/intro/install/
    tofu version

## Option B — Terraform

    # install: https://developer.hashicorp.com/terraform/install
    terraform version

Same HCL, same workflow (init / plan / apply / destroy). Wherever a solution
script calls tofu, terraform works identically.

## Local Docker (for the exercises that build real resources)

Several exercises provision *real* infrastructure with no cloud at all, using
the Docker provider against your local engine (containers, networks, volumes).
For those you need a running Docker (or a compatible engine):

    docker version

## The local-first providers

To stay free and reproducible, the exercises lean on providers that need
nothing but your machine:

- **local** — files on disk (local_file)
- **random** — stable pseudo-random names, ids, passwords
- **null** — triggers and provisioners, to teach the graph
- **tls** — private keys and self-signed certificates
- **docker** — containers/networks/volumes on your local engine (the "real
  infrastructure" feel, at zero cost)

Cloud-specific topics from the manual (provider authentication, remote backends
on a cloud) are shown as configuration you can read and reason about; the
hands-on parts are reproduced with the providers above, so nothing costs money.

## Verifying you are ready

    tofu version        # or: terraform version
    docker version      # only for the Docker-provider exercises

## Working through an exercise

Each exercise has a start/ (an incomplete configuration to finish) and a
solution/ (the tested answer). The usual loop is:

    tofu init
    tofu plan
    tofu apply
    # ... inspect ...
    tofu destroy

State files (terraform.tfstate*) and the .terraform/ working directory are
local scratch — never committed (see the repository .gitignore).

---

*IT — Questi esercizi girano interamente in locale e gratis: nessun account
cloud a pagamento è richiesto. OpenTofu è consigliato, ma va bene anche
Terraform (stesso HCL, stesso flusso).*
