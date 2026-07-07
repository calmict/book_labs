# Chapter 19 — The drawer or the room

**Level:** Advanced
**Estimated time:** 55–65 minutes
**Manual topics:** what "environment" really means (19.1), first strategy: workspaces (19.2), second strategy: separate directories (19.3), Terragrunt: the orchestrator (19.4)

## The idea

Dev, staging, prod: the same design, three different cities. Copy-pasting the
configuration three times is the photocopy chapter 1 taught us to fear — but an
environment is not just "the same code with a different name". An environment is
an *isolated copy* of the same infrastructure, with its own settings and — above
all — **its own state**. And chapter 13 already shouted it: environments must
never share the blast radius. A mistake in dev must not be able to queue, corrupt
or destroy prod.

This chapter compares the two main strategies, and puts both in your hands.

The first is the **workspace**: one codebase, one backend, but several states —
one per workspace. It is like keeping dev and prod in two *drawers* of the same
cabinet: you change drawer with a command (workspace select) and work on one or
the other. Maximally DRY, but with a downside: the cabinet is a single one, and
an apply run in the wrong drawer hits the wrong environment.

The second is **separate directories**: one folder per environment (dev/, prod/),
each with its own state, sharing the same *module* (chapter 17's prefab). It is
like giving each environment its own *room*, with the same floor plan but real
walls between them: more explicit, more boilerplate, but an isolation workspaces
do not give — destroying dev cannot graze prod.

And you will close with **Terragrunt**, the orchestrator that keeps the rooms
separate *without* making you copy-paste the boilerplate — you will see it as an
example to read.

## Goals

By the end you will be able to:

- say what an environment really is (different settings, separate state,
  non-shared radii);
- use workspaces: terraform.workspace, workspace new/select/list, and understand
  their risk;
- use separate directories with a shared module, and prove their isolation;
- compare the two strategies on DRY versus isolation, and choose with your head;
- recognise Terragrunt's role (DRY *on top of* separate directories).

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md.
- Docker running. Free ports: 8120, 8121 (workspaces) and 8122, 8123
  (directories).
- Chapters 13 (blast radius), 12 (backend and state) and 17 (modules): they
  combine here.

## Your task

### Part A — The drawer: workspaces (19.2)

In start/workspaces/ there is a configuration born *single-environment*: name and
port hard-coded. TODO 1 makes it *workspace-aware*. Complete the locals so they
derive the environment from terraform.workspace and pull the settings from a map:

    locals {
      settings = {
        dev  = { external_port = 8120 }
        prod = { external_port = 8121 }
      }
      env = terraform.workspace
      cfg = lookup(local.settings, terraform.workspace, local.settings["dev"])
    }

terraform.workspace is a special variable: it holds the name of the current
workspace. Now create the two drawers and apply in each:

    cd start/workspaces
    tofu init
    tofu workspace new dev
    tofu apply
    tofu workspace new prod
    tofu apply

Look at the drawers and the two containers born from one codebase:

    tofu workspace list
    docker ps --filter name=cap19-

The asterisk in workspace list marks the current one. Notice where the state
lands: in terraform.tfstate.d/dev/ and terraform.tfstate.d/prod/ — two states,
one backend. And here is the risk: the cabinet is a single one, the active drawer
is a *CLI state*. If you think you are in dev and you are in prod, your apply hits
prod. Workspaces are DRY but **share code and backend**: no wall between the
environments.

### Part B — The room: separate directories (19.3)

In start/directories/ the structure is different: a shared module (modules/webapp/,
chapter 17's prefab) and one folder per environment. dev/ is already complete: it
calls the module with development settings. TODO 2 asks you to complete
prod/main.tf on the same model, with production settings (port 8123):

    module "app" {
      source        = "../modules/webapp"
      environment   = "prod"
      external_port = 8123
    }

Apply the two environments, each from its own folder:

    cd ../directories/dev  && tofu init && tofu apply
    cd ../prod             && tofu init && tofu apply

Each folder has its *own* state, its *own* backend, its *own* init. Now the
isolation proof — destroy dev and look at prod:

    cd ../dev  && tofu destroy
    cd ../prod && tofu plan

Dev disappears, but prod's container stays alive, and prod's plan says No changes:
from the prod folder you cannot even *see* dev. Real walls: no command run in one
room can reach the other. It is chapter 13 applied to environments — separate
radii, by construction.

### Part C — The orchestrator: Terragrunt (19.4, reading)

Separate directories isolate beautifully, but they pay a price: the *boilerplate*
— the terraform block, the provider, the backend configuration — repeats in every
folder. Terragrunt is the tool that removes that copy-paste while keeping the
isolation. In start/directories/terragrunt.hcl.example you find an example to
read: a root file that *generates* the backend configuration (a different state
key per environment) and defines common providers once, and per-environment
folders that only include the root plus their own inputs. A single source of
truth for the boilerplate, rooms still separate. It is not OpenTofu nor Terraform:
it is a layer *above*, an orchestrator that conducts them.

### Part D — Choosing with your head (19.5, reflect)

Neither strategy is "right" in the absolute. Workspaces are unbeatable for DRY and
for ephemeral variants (a throwaway test environment, a branch); but they share
code and backend, and for real dev/prod that missing wall is a risk. Separate
directories cost some boilerplate (Terragrunt recovers it), but give the isolation
production deserves. The manual's rule of thumb: workspaces for variants *of the
same* deploy, separate directories for environments that must *not be able to
touch* each other.

### Cleanup

    # workspaces
    cd start/workspaces
    tofu workspace select dev  && tofu destroy
    tofu workspace select prod && tofu destroy
    tofu workspace select default
    # directories
    cd ../directories/prod && tofu destroy

## Definition of done

- With workspaces, terraform.workspace drove the name, and dev/prod had separate
  states in terraform.tfstate.d/.
- workspace list showed default, dev, prod, with the asterisk on the current one.
- With separate directories, dev and prod each had their own state and their own
  init.
- Destroying dev, prod's container stayed alive and prod's plan said No changes.
- You recognised, in the example, what Terragrunt generates (per-environment
  backend + common boilerplate).
- You answered the three questions in answers.md.

## The three questions

**a.** What an environment is: list the three things that really distinguish dev
from prod (not just the name). Why is *separate state* the most important, and
which chapter had already stated the principle (environments do not share the
radius)?

**b.** The drawer versus the room: describe the concrete risk of workspaces (why
it is easy to hit the wrong environment) and what exactly separate directories put
between dev and prod that workspaces do not. In what sense did your destroy of dev
*prove* the isolation?

**c.** Terragrunt and the choice: which problem of separate directories does
Terragrunt solve, and which one does it *not* (what stays separate)? And finally:
for an ephemeral test environment tied to a branch, would you choose the drawer or
the room — why?
