# Ansible — environment setup (non-binding)

These exercises run entirely on your machine, for free. No paid cloud account is
required to complete any of them. This guide is a **suggestion**: any recent
Ansible will do.

## The control node (your machine)

The machine you run Ansible from is the **control node**. It needs Python and
ansible-core:

    # install: https://docs.ansible.com/ansible/latest/installation_guide/
    ansible --version

A recent ansible-core (2.15+) is recommended, in a virtual environment so it
never collides with your system Python:

    python3 -m venv ~/.venvs/ansible
    . ~/.venvs/ansible/bin/activate
    pip install ansible-core

## The managed nodes (throwaway containers)

Ansible is **agentless**: it configures **managed nodes** over SSH, with nothing
installed on them but Python. To stay free and reproducible, the managed nodes
in these exercises are ephemeral local containers, driven by **Molecule** with
the Docker driver — one command up, one command down, teardown guaranteed. You
need a running Docker (or a compatible engine):

    docker version

Install Molecule and its Docker driver (pipx keeps it isolated):

    # install pipx: https://pipx.pypa.io/
    pipx install molecule
    pipx inject molecule 'molecule-plugins[docker]'
    molecule --version

Molecule is the standard way to give a role or a play a set of real, SSH-able
hosts and then throw them away. It doubles as the testing tool the manual
reaches in chapter 24, so learning it early pays off twice.

## The safety net (linting)

From the linting chapter onward you will also want ansible-lint:

    pipx install ansible-lint
    ansible-lint --version

## What stays local-first

Cloud-specific topics from the manual are shown as configuration you can read
and reason about; the hands-on parts are reproduced locally, so nothing costs
money:

- **Dynamic inventories** (chapter 21) — the AWS plugin is presented as a
  read-only example; the mechanism is exercised against the local containers.
- **Cloud secret managers** (chapter 19) — shown as configuration; the hands-on
  secret handling uses Ansible Vault and local lookups.

## Verifying you are ready

    ansible --version     # the control node
    docker version        # the engine behind the managed nodes
    molecule --version    # the throwaway-host driver (from the roles chapters on)

## Working through an exercise

Each exercise has a start/ (an incomplete configuration to finish) and a
solution/ (the tested answer). The usual loop is:

    molecule create       # bring the managed nodes up
    ansible-playbook -i <inventory> playbook.yml
    # ... inspect, re-run to see idempotence ...
    molecule destroy      # tear the managed nodes down

Generated artifacts (retry files, fetched data, molecule state) are local
scratch — never committed (see the repository .gitignore).

---

*IT — Questi esercizi girano interamente in locale e gratis: nessun account
cloud a pagamento è richiesto. La tua macchina è il control node; i managed node
sono container effimeri gestiti da Molecule (driver Docker), creati e distrutti
a comando. Ansible è consigliato in un virtualenv; Molecule fa da fabric dei
nodi usa-e-getta ed è anche lo strumento di test del capitolo 24.*
