# Chapter 28 — The standing theatre

**Level:** Cloud Architect

Chapter 27 gave you the wave release; chapter 26 the pipeline that launches it. But in both it is still
you — or a script — typing a command at a terminal, with inventories, credentials and "who-can-do-what"
kept in your head or scattered across files. That works for one person. It does not work for an
**organisation**: ten teams, hundreds of playbooks, thousands of nodes, reviewers and audits. At that
point the terminal is no longer enough — the way a troupe touring from town to town is no longer enough
once the city wants a resident season, with a home, a box office, a company roster and an archive.
**AWX** (and its supported edition, **Ansible Automation Platform**) is that standing theatre:
automation stops being a gesture at a terminal and becomes a **service** with a console, its own
permissions, and its own history. This chapter assembles its core objects — the **job template**,
**credentials with RBAC**, **workflows** — not by clicking in a UI, but by defining them **as code**,
versioned and validated before they go on stage. Because the Cloud Architect way to run the platform is
not "click in the UI": it is GitOps here too.

## Objectives

- Why the **terminal is no longer enough** at organisation scale (28.1).
- **AWX and Ansible Automation Platform**: who is who (28.2).
- The central concept: the **job template** (28.3).
- **Credentials, RBAC and audit**: governing access (28.4).
- **Workflows**: chaining jobs with success and failure branches (28.5).
- The other building blocks: **EE, scheduling, EDA** (28.6).
- **Good habits** with the platform (28.7).

## Prerequisites

- The chapter 6 venv with **ansible-core** (in start/requirements.txt): no need to install AWX — here
  you define and validate its objects *as code*, offline.
- The **wave release** of chapter 27: the playbooks the job templates run are exactly that deploy (plus
  smoke-test and rollback).
- The **secret lookups** of chapter 19: the credential does not *hold* the key, it *references* it.
- The **pipeline** of chapter 26: this exercise is the gate that validates the objects *before* the
  import into AWX — GitOps applied to the platform itself.

## The scenario

start/ has two parts. project/ is what AWX calls a **project**: the real playbooks the platform will
run — deploy.yml, smoke.yml, rollback.yml. platform/objects.yml is AWX's **object graph** defined as
code: projects, inventories, credentials, job templates, RBAC grants and a workflow. No secret lives
here: only a reference to where the platform will fetch it. Three gaps leave the graph incomplete or
unsafe; you close them, and a **pre-import validator** (the one you would run in CI before loading it
all into AWX) confirms the graph resolves and is safe.

Set up the environment:

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    cd start

### Phase 1 — Why the terminal is no longer enough (28.1)

So far automation has been an individual act: open a terminal, launch a playbook. At organisation scale
that model breaks on four fronts. **Access**: who can launch what, on which nodes? A terminal does not
know. **Secrets**: credentials end up on laptops. **Traceability**: who launched that deploy, when,
with what result? Nobody knows. **Repeatability and coordination**: chaining deploy → test → rollback,
on a schedule, with approvals. You need a place where automation *lives* — with a roster (RBAC), a box
office (who gets in), an archive (audit) and a programme (workflows, scheduling). That place is the
platform.

### Phase 2 — AWX and Ansible Automation Platform: who is who (28.2)

They are the same theatre, in two productions. **AWX** is the upstream project, free and community,
where features appear first — the edition to experiment with. **Ansible Automation Platform (AAP)** is
Red Hat's commercial, supported version, with SLAs, certified content and the official Execution
Environments — the edition for the organisation's production. Same object model, same API: job
templates, credentials, workflows. What you learn on one holds on the other; here you work on the
objects, which are identical.

### Phase 3 — The central concept: the job template (28.3 — TODO 1)

A **job template** is the recipe for a launch: which **playbook**, taken from which **project** (a git
repo), against which **inventory**, with which **credentials**. It is the object that turns "a playbook
in the repo" into "a button someone with the right permissions can press". Open platform/objects.yml:
the deploy job template is incomplete. Complete **TODO 1**, binding it to the objects it must use —

    job_templates:
      - name: deploy
        project: infra-playbooks
        inventory: production
        playbook: deploy.yml
        credentials: [deploy-ssh]
        limit: webfarm

Every reference must **resolve**: the project, the inventory and the credential must exist among the
defined objects, and the playbook must really exist in the project. A template pointing at a
non-existent inventory or a missing playbook is a button that, once pressed, fails — and that is exactly
what the validator rejects. Question a.

### Phase 4 — Credentials, RBAC and audit: governing access (28.4 — TODO 2)

Here the platform earns its real value. Three ideas:

- **Credentials**: the secret (an SSH key, a token) is **not written in the graph**. The credential
  *references* it — the platform resolves it at run time from a secret manager (chapter 19). Look at
  deploy-ssh: the secret field is a lookup, not a key in plaintext. The validator rejects any plaintext
  secret.
- **RBAC**: who can do what. The principle is **least privilege**: give the narrowest role that
  suffices, on the most specific resource. The deployers team must not administer the organisation: it
  must be able to **execute** the deploy job template, and nothing else.
- **Audit**: every launch leaves a trace — who, when, with what outcome. It is not an object you define,
  it is a property you get simply by going through the platform instead of the terminal.

In the graph the RBAC grant is far too broad. Complete **TODO 2**: narrow it to least privilege —

    rbac:
      - team: deployers
        role: execute
        resource: job_template:deploy

The validator rejects broad roles (admin, system administrator) and grants over whole scopes (an
organisation, not a resource): it insists on a narrow role over a specific resource that exists.
Question b.

### Phase 5 — Workflows: chaining jobs (28.5 — TODO 3)

A single job template launches one playbook. A **workflow** chains several into a graph, with distinct
branches for **success** and **failure**. It is the choreography of chapter 27 raised to the platform
level: deploy; if it goes well, launch the smoke-test; if the deploy or the smoke fail, launch the
rollback. In the graph the nodes are there but the edges are missing. Complete **TODO 3**: connect the
nodes —

    workflows:
      - name: release
        nodes:
          - id: n_deploy
            job_template: deploy
            success_nodes: [n_smoke]
            failure_nodes: [n_rollback]
          - id: n_smoke
            job_template: smoke-test
            failure_nodes: [n_rollback]
          - id: n_rollback
            job_template: rollback

The validator checks it is a **well-formed DAG**: every node runs an existing job template, every edge
points at an existing node, there is exactly one root, there are no cycles — and there is a **failure
branch leading to the rollback**. A workflow that only knows how to go forward, with no way out when
something breaks, is half the job.

### Phase 6 — The other building blocks: EE, scheduling, EDA (28.6)

The platform is wider than this. **Execution Environments (EE)** are container images with Python,
ansible-core and the collections: the job does not run in an improvised venv but in a **reproducible,
versioned** environment — the same idea as chapter 24, standardised for the whole organisation.
**Scheduling** launches job templates on a calendar (the nightly compliance run). **EDA (Event-Driven
Ansible)** flips the direction: no longer "a person launches", but "an event launches" — an alert, a
webhook, a log line fires a rulebook. These are the blocks that turn the theatre from "the curtain
rises when someone decides" into "the season runs itself".

### Phase 7 — Good habits with the platform (28.7)

- **Configuration as Code**: the platform's objects (templates, credentials, workflows) live in git and
  are loaded by automated imports, not by hand in the UI. It is what you did here, and it is what lets a
  validator stop an error *before* the import (chapter 26).
- **Least privilege, always**: the narrowest role, on the most specific resource. Broad RBAC is
  convenient today and an incident tomorrow.
- **The secret is referenced, not written**: never a key in the graph; always a lookup to a secret
  manager (chapter 19).
- **Reproducible environments**: versioned EEs, not improvised venvs on the control node.
- **Every launch leaves a trace**: go through the platform, not the terminal, so the audit exists by
  construction.

## Done when

- The deploy job template is complete and every reference resolves (TODO 1): project, inventory and
  credential exist, and the playbook is in the project.
- The RBAC grant is least privilege (TODO 2): a narrow role (execute) on a specific resource (the job
  template), not admin over an organisation.
- The workflow is a well-formed DAG with a failure branch to the rollback (TODO 3).
- The pre-import validator accepts the graph: references resolve, secrets are referenced not written,
  access is scoped, the workflow is valid.

## How it is verified

solution/run.sh is the **pre-import gate**, all locally and offline (no AWX required):

1. **The project's playbooks are real**: syntax-check on deploy.yml, smoke.yml, rollback.yml — the job
   templates point at playbooks that exist and are well formed.
2. **The graph is valid and safe**: the validator accepts the completed graph — references resolved, no
   plaintext secret, RBAC scoped, workflow a DAG with a failure branch.
3. **The checks actually bite**: run.sh introduces, one at a time, a dangling reference, an over-broad
   RBAC grant, a plaintext secret and a workflow with no failure branch — and requires the validator to
   **reject** each. It is exactly what AWX (or your review) would reject.

## Reflection questions

**a.** A job template binds a playbook to a project, an inventory and a credential. Why is this
"packaging" what lets a non-expert safely launch an automation they do not fully understand — and what
would be lost by giving that person, instead, terminal access with the same playbook?

**b.** Least privilege says: narrowest role, most specific resource. Give a concrete example of an
incident that an execute-on-the-single-template grant prevents but an admin-over-the-organisation role
does not. Why does the audit (who-did-what) lose most of its value if everyone has broad roles?

**c.** The workflow has a failure branch to the rollback. Why is a workflow that only knows how to "go
forward on success" as dangerous as chapter 27's release with no brake? What is the relationship between
failure_nodes → rollback here and a playbook's block/rescue/always?

## Cleanup

Nothing to tear down: no AWX, no container, no remote node. The graph is just text files. Close the
venv with:

    deactivate

## Where it leads

With chapter 28 automation has a home: the platform's objects defined as code, access governed, jobs
chained into workflows with a way out. **It closes the Cloud Architect tier and closes the manual**:
from the three ways to break of chapter 1, you have reached orchestrating a thousand nodes from a
platform with its own governance. The conductor now has a standing theatre. From here there are no new
concepts to learn, only a craft to sharpen: the **appendices** give you the desk tools — the command
cheat sheet, the essential Jinja2 filters, the map of variable precedence, the glossary, the
troubleshooting, and the resources for certification — because a theatre, once built, keeps its doors
open every night.
