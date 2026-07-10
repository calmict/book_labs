# Chapter 6 — The baton

**Level:** Foundational

For five chapters you studied the score without ever raising the baton. Now you pick
it up: **you install Ansible**. But like a good conductor you do not dirty the stage
— you install it in an **isolated** environment (a virtualenv), so you never touch
the system Python. Then you tune the players: **you prepare the nodes** you will
configure in the coming chapters.

## Objectives

- **ansible-core** versus the **ansible** package: the engine + the ansible.builtin
  modules, against the bundle with hundreds of community collections.
- The installation methods (system / pip / pipx) and why the **venv** is your
  salvation (isolation).
- Installing ansible-core in a venv and making it **reproducible** with a
  requirements.txt.
- **Verifying**: ansible --version, the command family, the smoke test
  ansible localhost -m ping.
- **Preparing the target nodes**: the lab you will use from here on.

## Prerequisites

- python3 (3.9+) with the venv module.
- Docker for the target nodes.
- Network: pip downloads ansible-core, and preparing the nodes downloads sshd +
  python.

## Step by step

### Phase 1 — The clean stage (the virtualenv)

Open start/setup.sh and complete **TODO 1**: create a virtualenv and start using it.

    python3 -m venv .venv
    . .venv/bin/activate

Why a venv? Because installing Ansible into the *system* Python dirties it and
creates conflicts between projects; the venv is an isolated box you can throw away
whenever you like. (Alternatively, **pipx** installs Ansible as an isolated app with
one command: great in production; here we use an explicit venv to *see* it.)

### Phase 2 — Reproducibility (requirements.txt)

Complete **TODO 2** in start/requirements.txt: **pin** the ansible-core version, so
anyone can rebuild an environment identical to yours.

    ansible-core==2.15.13

Then install from it:

    pip install -r requirements.txt

The key distinction: **ansible-core** is the engine plus the ansible.builtin
modules; the **ansible** package is core *plus* hundreds of community collections
(community.general, ansible.posix…). For these exercises core is enough.

### Phase 3 — Verification and the anatomy of the commands

    ansible --version

It tells you the installed core, the Python in use and the active config file. Then
the **family** of commands, each a trade:

- ansible — an order on the fly (ad-hoc, chapter 9)
- ansible-playbook — runs playbooks (chapter 10)
- ansible-config — inspects the configuration (chapter 7)
- ansible-doc — the module documentation
- ansible-galaxy — collections and roles (chapters 16-17)

Now the **smoke test**, without touching any server:

    ansible localhost -m ping

The answer: pong. You have just run your first module. Remember the "journey of a
task" from chapter 2? Here it is automated — and localhost is a special case that
does not even go through SSH.

### Phase 4 — Core versus package, in numbers

With an isolated collection path, count the modules of **core alone**:

    ANSIBLE_COLLECTIONS_PATH=/tmp/empty ansible-doc -l | wc -l

About **74**, all ansible.builtin (ping, copy, file, service, apt, command…). The
full ansible package adds hundreds more: those are the community collections. Core is
small and stable on purpose; you install collections when you need them (chapter 17).

### Phase 5 — Tuning the players (the target nodes)

A managed node, as you know from chapter 2, needs only SSH and Python. Prepare two:

    bash start/nodes.sh up

It creates cap06-web and cap06-db, with sshd + python3. Verify they answer:

    ssh -p 2206 -i /tmp/cap06-lab/key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1 hostname
    ssh -p 2207 -i /tmp/cap06-lab/key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1 hostname

They are ready: in chapter 8 you will put them in an **inventory** and Ansible will
call them by name.

## Done when

- The venv exists and ansible --version shows **ansible-core**.
- The **five commands** answer.
- ansible localhost -m ping → **pong**.
- The two target nodes are **reachable over SSH**.

## Questions to reflect on

**a.** Why is it better to install Ansible in a venv (or with pipx) instead of into
the system Python? What can break if you put it into the system?

**b.** What is the difference between ansible-core and the ansible package, and why
is core enough for these exercises? When would you need the full bundle?

**c.** ansible localhost -m ping worked without an inventory and without SSH. Why is
localhost a special case, and what is still missing — which you will see in chapter 8
— to ping cap06-web?

## Cleanup

    bash start/nodes.sh down
    deactivate 2>/dev/null; rm -rf .venv

## Where it leads

You have the conductor (Ansible) and the players (the nodes). In chapter 7 you give
it the score of rules (ansible.cfg); in 8 the address book (the inventory) to call
them by name; in 9 the first ad-hoc order — a ping on cap06-web, no longer just on
localhost.
