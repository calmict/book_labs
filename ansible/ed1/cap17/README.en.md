# Chapter 17 — The shared repertoire

**Level:** Intermediate

The role of chapter 16 is yours, written at home. But thousands of people have already
written and shared roles and modules for every conceivable task: managing firewalls,
databases, cloud providers, system services. You do not have to re-compose what already
exists — you can draw on the **shared repertoire**. The place is **Ansible Galaxy**; the unit
of distribution is the **collection**; and the way to cite each piece precisely is the **fully
qualified name**, the FQCN. This chapter — the last of the Intermediate tier — teaches you to
stand on the shoulders of giants without losing reproducibility.

## Objectives

- **On the shoulders of giants**, and from roles to **collections** (17.1, 17.2).
- The mystery of the dotted names: the **FQCN** (17.3).
- **Installing** a collection (17.4) and declaring it in **requirements.yml** (17.5).
- **Where** collections end up and how to keep them **with the project** (17.6).
- **Using** it in a playbook (17.7).
- **Automation Hub** and private repositories (17.8); **publishing** (17.9).
- **Good habits** with Galaxy and collections (17.10).

## Prerequisites

- The chapter 6 venv (or start/requirements.txt).
- Network: we download a collection from galaxy.ansible.com (like pip from PyPI).
- The roles of chapter 16; the lock/pin of chapter 7; the ansible.builtin FQCN already glimpsed.
- (No nodes: this chapter works on the **control node** — installing and using a collection
  happens at home.)

## The scenario

You want to manage an INI file. A module already does it well — **community.general.ini_file** —
but it is not among the always-present ones: it lives in the community's large collection. You
install it, declare it as a pinned dependency, keep it inside the project, and use it. No
remote machine: everything on the control node.

## Step by step

### Phase 1 — From roles to collections, and the FQCN

A role (ch. 16) packages *one* capability. A **collection** packages *many* things — modules,
roles, filters, plugins — under a **namespace**. You have been using one all along without
knowing: **ansible.builtin**, the built-in collection, is where copy, file, template come from.
Another, huge one, is **community.general**.

This is why the names are **dotted** (17.3): the **FQCN** — Fully Qualified Collection Name —
has three parts, *namespace.collection.module*:

    ansible.builtin.copy          # namespace ansible, collection builtin, module copy
    community.general.ini_file    # namespace community, collection general, module ini_file

Why the formality? Because two different collections might have a module with the same short
name (ini_file): the FQCN says *exactly* which one, unambiguously — Question a.

### Phase 2 — Install and declare: requirements.yml (TODO 1)

You do not download collections by hand one at a time: you **declare** them. Complete **TODO 1**
in start/requirements.yml:

    ---
    collections:
      - name: community.general
        version: "8.6.0"

and install everything with one command:

    ansible-galaxy collection install -r requirements.yml

Note the **pinned version** ("8.6.0"): it is the same principle as chapter 7's pin (tofu).
Without it you would get "the latest available" — and tomorrow that would be a different one,
risking a playbook that changes behaviour on its own.

### Phase 3 — Where they end up, and keeping them with the project (TODO 2)

By default collections go to **~/.ansible/collections**: global, shared across all your
projects, at whatever version happens to be there. For a serious project that is not enough:
you want whoever clones it to get the *same* collections at the *same* versions. The solution
is to keep them **inside the project**. Complete **TODO 2** in start/ansible.cfg:

    [defaults]
    collections_path = ./collections

Now ansible-galaxy install downloads into ./collections, next to the code. Project +
requirements.yml (the pin) + collections_path (the place) = reproducibility: like chapter 7's
lock file — Question b. (The ./collections folder is **not** committed: it is regenerated from
requirements.yml, as you do with downloaded dependencies.)

### Phase 4 — Using it in a playbook (TODO 3)

Now the collection's module is at hand. Complete **TODO 3** in start/site.yml: the task that
manages the INI, called by its **FQCN**:

    - name: Manage an INI key with a collection module
      community.general.ini_file:
        path: "{{ conf_path }}"
        section: server
        option: port
        value: "8080"
        mode: "0644"

The rest of the playbook uses **ansible.builtin** modules (file, slurp, debug) — the contrast
is right there: built-ins without a thought, the collection cited in full. Run it and read:

    [server]
    port = 8080

### Phase 5 — Automation Hub, private repositories, and publishing

- Galaxy is the community's **public** repertoire. In a company one often uses **Automation
  Hub** (17.8): collections *certified* by Red Hat, or an internal **private** repository, for
  guaranteed, controlled content. The mechanism is the same: you declare, pin, install — only
  the source changes.
- And you can **give back** (17.9): package your own collections and publish them, so the next
  person stands on *your* shoulders.

### Phase 6 — Good habits

- **Always the FQCN**: in serious playbooks, community.general.ini_file, not ini_file. No
  ambiguity, and you can read where each module comes from.
- **Pin the versions** in requirements.yml: reproducibility, not surprises.
- **Keep collections with the project** (collections_path); regenerate them from
  requirements.yml.
- **Do not trust blindly**: a third-party role or collection runs **with your privileges**
  (become, ch. 11). Read what it does before running it as root — Question c.

## Done when

- requirements.yml installs **community.general** (pinned version) into **./collections**
  (inside the project).
- The playbook uses **community.general.ini_file** by FQCN and writes [server] port = 8080 to
  the INI.
- Re-running → **changed=0** (the collection module is idempotent like the built-ins).
- ansible-galaxy collection list shows the pinned version, from the project's path.

## Questions to reflect on

**a.** Why do you write community.general.ini_file in full, and not just ini_file? What does
the fully qualified name (FQCN) solve the day two different collections both offer a module
called ini_file?

**b.** Collections could sit comfortably in ~/.ansible, shared across all projects. Why is it
better to keep them *inside the project* (collections_path) and pin their version in
requirements.yml? Tie the answer to chapter 7's lock file and the idea of reproducibility.

**c.** Installing a third-party collection means running code written by others — and your
playbooks often run with become (ch. 11), that is, as root. Why is it unwise to install the
first role you find and run it, and what do you check *before* giving it your privileges?

## Cleanup

Nothing to tear down: this chapter powers no nodes. If you like, delete the ./collections
folder (it regenerates from requirements.yml).

## Where it leads

You close the Intermediate tier: you can write roles and draw on the world's repertoire. One
account is still open from chapter 11 — the sudo password left *in plaintext*. Chapter 18 opens
the Advanced tier and finally puts it in a safe: **Ansible Vault**, encrypting secrets inside
your files.
