# Chapter 24 — The throwaway stage

**Level:** Advanced

Chapter 23 gave you three nets — syntax-check, lint, check mode — but none of them actually *runs*
the role against a real system. A clean lint and an empty-theatre rehearsal tell you the playbook
is *well written* and what it *would change*, not that the role **works**: that it starts from
scratch, converges, is idempotent, and leaves the system in the right state. That is the wall
chapter 23 cannot cross. Molecule tears it down: it stands up a **real but throwaway** environment
(a container), applies the role, checks idempotence and result, and tears it all down — one command
up, one command down. It is the rehearsal on a real stage, with the certainty that you can always
rebuild it from nothing.

## Objectives

- The **wall of chapter 23** and why you need a test that truly executes (24.1).
- **What Molecule is**: the throwaway environment as a test bench (24.2).
- **Installation and first scenario** (24.3).
- **Anatomy of a scenario**: driver, platforms, provisioner, verifier (24.4).
- The **lifecycle**: create, converge, idempotence, verify, destroy (24.5).
- **Writing the verifications** with Testinfra: a second pair of eyes (24.6).
- **Working in phases** during development (24.7).
- **More scenarios, more distributions** (24.8).
- The **good habits** with Molecule (24.9).

## Prerequisites

- The chapter 6 venv, plus **molecule**, the **docker** driver and **testinfra** (in start/requirements.txt).
- A running local **Docker engine** (Molecule creates and destroys its containers there, never yours).
- The **community.docker** and **ansible.posix** collections (in start/requirements.yml): the driver uses them to talk to the daemon.
- A role to test: chapter 16 taught you to *write* a role; here you learn to *test* it.

## The scenario

start/cap24_app/ is a tiny role that writes a directory and a config file and leaves a deploy
marker. Around it sits a **Molecule scenario** (the molecule/default/ folder) that is almost
complete, but has three gaps. You fill them by putting the role through Molecule's full cycle,
until "molecule test" is green from top to bottom.

Prepare the environment:

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    ansible-galaxy collection install -r start/requirements.yml
    cd start/cap24_app

### Phase 1 — The wall of chapter 23 (24.1–24.2)

Chapter 23 stops short of the truth. syntax-check and lint do not execute; check mode *simulates*
against the current state, but it assumes an existing system and does not prove that the role works
**from scratch, twice in a row, for real**. Molecule closes the loop: it takes a clean system (a
freshly created container), applies the role for real, re-checks by applying it a second time
(idempotence), inspects the result with independent eyes, and then throws it all away. It is not a
simulation: it is real execution, made repeatable by the throwaway.

### Phase 2 — What Molecule is (24.2)

Molecule orchestrates the testing of a role. Around the role it puts a **scenario**: how the test
system is born (the **driver**: here Docker), which role to apply (the **provisioner**: Ansible,
with a converge.yml playbook), and how to verify the result (the **verifier**: here Testinfra). A
single command, "molecule test", runs the whole sequence and guarantees the final cleanup.

### Phase 3 — Anatomy of a scenario (24.4 — TODO 1)

Open molecule/default/molecule.yml. A scenario has four sections:

    driver:        # how the test system is born (docker)
    platforms:     # WHICH systems: name + image
    provisioner:   # who applies the role (ansible)
    verifier:      # who checks the result (testinfra)

Complete **TODO 1**: declare the platform and the verifier —

    platforms:
      - name: cap24-instance
        image: python:3.12-slim
        pre_build_image: true
    verifier:
      name: testinfra

The image is not chosen at random: the provisioner needs **Python** inside the container (Ansible
runs its modules there), so you start from an image that already ships it (pre_build_image: true =
"use this image as is, do not build it"). The name cap24-instance is how Molecule will name the
container: distinct, so it never touches your other containers.

### Phase 4 — The lifecycle (24.5 — TODO 2)

The heart of Molecule is a sequence of phases:

    create       # create the container
    converge     # apply the role (converge.yml)
    idempotence  # apply the role A SECOND TIME: it must report changed=0
    verify       # run the verifications (testinfra)
    destroy      # destroy the container

The **idempotence** phase is the strictest and the most honest: it re-runs converge and demands
**zero changes**. It is the acid test of chapter 5, automated: a correct role, applied twice, the
second time changes nothing.

Look at the role's tasks/main.yml: the last task leaves a marker with a command —

    - name: Stamp a deploy marker once
      ansible.builtin.command: touch /etc/cap24app/deployed

A command is a **doorbell** (chapters 5 and 9): it reports *changed* every time. On the second
apply, idempotence catches it and fails, naming the offending task. Complete **TODO 2**: make the
task idempotent with the **creates** guard —

    - name: Stamp a deploy marker once
      ansible.builtin.command: touch /etc/cap24app/deployed
      args:
        creates: /etc/cap24app/deployed

creates tells Ansible: "if this file already exists, skip the command". First apply → creates
(changed); second → skipped (ok). Now the whole cycle can close green. Run it:

    molecule test

You will see the sequence: create, converge (changed), idempotence (changed=0, "Idempotence
completed successfully"), verify, destroy. Question b.

### Phase 5 — Writing the verifications (24.6 — TODO 3)

converge tells you that Ansible *believes* it put things right (its own ok/changed). But it is
Ansible judging itself. **Testinfra** is a second pair of eyes: it inspects the **real** system —
files, permissions, contents, services — independently of what Ansible reported. The verifications
live in molecule/default/tests/test_default.py and are ordinary pytest tests.

Complete **TODO 3**: write the assertions about the role's result —

    testinfra_hosts = ["all"]

    def test_config_directory(host):
        d = host.file("/etc/cap24app")
        assert d.is_directory
        assert d.mode == 0o755

    def test_config_file(host):
        f = host.file("/etc/cap24app/app.conf")
        assert f.exists
        assert f.mode == 0o644
        assert "workers = 4" in f.content_string

The host object is the lens: host.file(...), host.user(...), host.package(...), host.service(...).
If an assertion is false — the file is missing, the permission is loose, the content is wrong —
verify fails. It is the difference between "Ansible says it did it" and "the system confirms it is
done". Question c.

### Phase 6 — Working in phases (24.7)

"molecule test" always destroys at the end: perfect for CI, awkward while you develop. During
development you work in phases, reusing the same container:

    molecule create      # create once
    molecule converge    # apply the role (repeat on every edit: fast)
    molecule login       # step into the container to poke around
    molecule verify      # run only the verifications
    molecule destroy     # throw it away when you are done

The tight loop is converge → edit → converge: no waiting to recreate the container. "molecule test"
remains the final judge, the one that starts from scratch and guarantees cleanup.

### Phase 7 — More scenarios, more distributions (24.8)

A serious role should be tested on more than one system. Two routes:

- **More platforms** in the same scenario: add entries under platforms and Molecule creates several
  containers, applying and verifying on all of them. Beware: different distributions have different
  needs — an Alpine image, for instance, has no bash and must be kept alive with an explicit
  command:

      - name: cap24-alpine
        image: python:3.12-alpine
        pre_build_image: true
        command: /bin/sh

- **More scenarios**: sibling folders under molecule/ (molecule/default/, molecule/hardening/),
  each with its own molecule.yml, converge.yml and verifications. You select them with
  "molecule test -s hardening". One scenario per way the role is used.

### Phase 8 — The good habits (24.9)

- **Idempotence always in the cycle**: it is the check that unmasks doorbells disguised as switches
  (commands without creates/changed_when).
- **Independent verification**: Testinfra looks at the system, not at Ansible's report. A
  "converged" role with no verifications is a promise not kept.
- **In phases while you develop, full test before you ship**: fast converge to iterate, "molecule
  test" from scratch as the judge.
- **Throwaway containers, never yours**: Molecule manages only the instances it names; teardown is
  guaranteed, it leaves no residue.
- **More distributions** if the role must run on more than one: better to find the differences here
  than in production.

## Done when

- molecule.yml declares the platform and the testinfra verifier (TODO 1).
- The marker task has the creates guard (TODO 2): the **idempotence** phase passes (changed=0).
- The testinfra verifications are written (TODO 3) and the **verify** phase passes.
- "molecule test" is green from start to finish: create, converge, idempotence, verify, destroy —
  and it leaves no container behind.

## Questions to reflect on

**a.** Chapter 23 gave you lint and check mode; Molecule creates a real system and runs the role on
it for real. In what sense does this *prove* something lint and check mode cannot? What does it add
that the environment is created **from scratch** and then **destroyed**?

**b.** The idempotence phase re-applies the role and demands changed=0. Why is "apply it twice, the
second time it must change nothing" the strongest — and cheapest — proof of a role's correctness?
What does a non-idempotent task (a command without creates) that slips past this phase cost, in
concrete terms?

**c.** converge reports ok/changed: it is Ansible judging itself. Testinfra inspects the real
system. Why does an **independent** check catch errors that converge's own report cannot? Give an
example of a role that converges "green" but leaves the system wrong.

## Cleanup

Molecule tears down by itself at the end of "molecule test". If you worked in phases, close with:

    molecule destroy

No residue: the throwaway containers die with the teardown, your containers stay intact.

## Where it leads

You can write a role (ch. 16), keep it clean (ch. 23) and now **test** it on a real system,
repeatedly, from scratch (ch. 24). It closes the Advanced tier. But so far you have orchestrated a
handful of nodes: what happens when they become **a thousand**? **Chapter 25** opens the Cloud
Architect tier with **performance at scale** — forks, strategies, pipelining, taming facts —
because at a thousand nodes even one extra second per host becomes a wait that never ends.
