# Chapter 18 — The paperwork, not the buildings

**Level:** Advanced
**Estimated time:** 55–65 minutes
**Manual topics:** the problem: the address is the identity (18.1), the moved block: renaming safely (18.2), the removed block: forgetting without destroying (18.3), import: adopting the existing (18.4), the state commands: the manual scalpel (18.5)

## The idea

Chapter 17 closed with a trap: by wrapping resources in a module you changed
their *address*, and chapter 15 warned us the address *is* the identity. Rename a
resource in the code, and Terraform does not see a new nameplate: it sees a
resource gone and a new one born — it demolishes and rebuilds. For a container
that is an annoyance; for a production database it is a disaster.

But chapter 11's notebook — the state — is only a *map* between addresses in the
code and real objects. And a map can be corrected without touching the
territory. This chapter gives you four ways to **change the paperwork without
touching the buildings**:

- **moved** — I change the nameplate: "the resource I called app is now called
  frontend". Same building, new name on the register;
- **removed** — I tear the page out of the notebook but leave the building
  standing: Terraform stops managing it, reality remains;
- **import** — I add a page for a building someone put up by hand, never
  registered: I adopt it;
- **the state commands** — the manual scalpel (state list, show, mv, rm) for
  when you need to operate on the notebook by hand.

The thread through all four: no building is demolished. You will prove it by
checking, at each step, that the container was not recreated — same ID, still
standing.

## Goals

By the end you will be able to:

- explain why renaming a resource naively causes destruction and recreation (the
  address is the identity);
- rename safely with a moved block, and verify the resource was not touched;
- stop managing a resource without destroying it with a removed block;
- adopt an existing resource, created outside Terraform, with an import block;
- use the tofu state commands (list, show, mv, rm) as a manual scalpel, and know
  when they are still needed.

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md.
- Docker running. Free port: 8110.
- Chapters 11 (state as a map), 15 (the address is identity) and 17 (modules):
  they come together here.

## Your task

### Phase 0 — The problem: the address is the identity (18.1)

In start/ you find two managed containers: app (on 8110) and cache. Apply them
and note the real IDs — they are the proof of no harm:

    cd start
    tofu init
    tofu apply
    docker inspect -f '{{.Id}}' cap18-app

Now create an *orphan* volume by hand, as a colleague would leave it with a quick
command (you will need it in Phase 3):

    docker volume create cap18-data

Try the trap. In main.tf rename the resource from docker_container "app" to
docker_container "frontend" (only the Terraform label, leave name = "cap18-app"),
and ask for the plan:

    tofu plan

Read the disaster: docker_container.app will be destroyed,
docker_container.frontend will be created. You changed nothing real — only the
nameplate in the code — and Terraform wants to demolish and rebuild. Do not
apply: Phase 1 makes it safe.

### Phase 1 — moved: changing the nameplate (TODO 1)

TODO 1 asks you to add, next to the renamed resource, a moved block that tells
the notebook "I am the same, I only changed name":

    moved {
      from = docker_container.app
      to   = docker_container.frontend
    }

Ask for the plan again:

    tofu plan

Now: docker_container.app has moved to docker_container.frontend, and Plan: 0 to
add, 0 to change, 0 to destroy. No bulldozer: just one corrected line in the
register. Apply and verify the container is the same as before:

    tofu apply
    docker inspect -f '{{.Id}}' cap18-app

Same ID as Phase 0: the building was not touched.

### Phase 2 — removed: forgetting without destroying (TODO 2)

The cache moves to another team: you want Terraform to *stop managing* it, but
without switching it off. TODO 2 asks you to **remove** the
docker_container "cache" resource from the code and put a removed block in its
place:

    removed {
      from = docker_container.cache
    }

Ask for the plan and apply:

    tofu plan
    tofu apply

The plan says: docker_container.cache will be removed from the OpenTofu state but
will not be destroyed. After the apply, the cache is no longer in the notebook
(tofu state list does not list it) — but the container is still alive:

    docker inspect -f '{{.State.Status}}' cap18-cache

Page torn from the register, building still standing.

> **OpenTofu vs Terraform note.** This is one of the rare points where the syntax
> diverges. In OpenTofu the removed block simply *forgets*. In Terraform you must
> be explicit with an inner lifecycle:
>
>     removed {
>       from = docker_container.cache
>       lifecycle {
>         destroy = false
>       }
>     }
>
> Same effect (forget without destroying); just two dialects.

### Phase 3 — import: adopting the existing (TODO 3)

The orphan volume you made by hand in Phase 0 remains: it exists in reality, but
Terraform does not know it. TODO 3 adopts it with an import block plus the
resource that describes it:

    import {
      to = docker_volume.data
      id = "cap18-data"
    }

    resource "docker_volume" "data" {
      name = "cap18-data"
    }

The id is the real identifier the provider understands — for a volume, its name.
Ask for the plan and apply:

    tofu plan
    tofu apply

The plan says docker_volume.data will be imported, and Plan: 1 to import, 0 to
add, 0 to change, 0 to destroy: adopted with no changes, because the resource you
wrote matches reality. Run tofu plan again: No changes. The building put up by
hand is now on the register, without having been rebuilt.

### Phase 4 — The manual scalpel (18.5)

The moved/removed/import blocks are the *declarative* way, modern and reviewable
in a plan. But there is also the imperative scalpel, the tofu state commands —
handy for one-off operations or ones a block cannot express. Look and try:

    tofu state list
    tofu state show docker_container.frontend

state list is the notebook's index; state show opens a page. And for surgical
operations by hand there are state mv (the imperative equivalent of moved) and
state rm (which forgets from the state — like removed, but leaving no trace in a
block). Try one, then put it back:

    tofu state mv docker_container.frontend docker_container.web_front
    tofu state list
    tofu state mv docker_container.web_front docker_container.frontend

A powerful scalpel with no safety net: no plan announces it, no review reviews
it. The declarative blocks exist precisely to make these cuts visible in a plan —
use the commands only when you truly need them.

### Phase 5 — Tying up Part 5 (reflect)

You have learned to evolve the code without the infrastructure paying the price:
the map is corrected, the territory stays. It is Part 5's theme, maintenance. The
next step is managing *multiple environments* together — dev, staging, prod —
without copy-paste, and without a mistake in dev grazing prod: chapter 19.

### Cleanup

    tofu destroy
    docker rm -f cap18-cache
    docker volume rm cap18-data

(The cache and the volume, no longer managed or adopted after the destroy, must
be removed by hand: they are the echo of the boundary between what Terraform
manages and what it does not.)

## Definition of done

- In Phase 0, the naive rename produced a plan with destroy + create.
- With moved (TODO 1), the plan was 0 to add, 0 to change, 0 to destroy, and the
  container's ID stayed unchanged.
- With removed (TODO 2), the cache disappeared from the state but the container
  stayed in the running state.
- With import (TODO 3), the orphan volume entered the state (1 to import) and the
  next plan said No changes.
- You used tofu state list/show and tried a state mv round trip.
- You answered the three questions in answers.md.

## The three questions

**a.** The address is the identity: explain why, without moved, renaming
docker_container.app to docker_container.frontend destroys and recreates, even
though the real container (name, image, port) is identical. What does Terraform
actually compare when it decides destroy+create — the real name or the address in
the notebook? Connect it to chapter 11 (what the state maps).

**b.** removed versus a destroy: what is the difference between removing a
resource from the code *without* a removed block and removing it *with* the
removed block? In which case does the container switch off and in which does it
stay alive? And why does the syntax differ between OpenTofu and Terraform, while
achieving the same result?

**c.** import and the scalpel: why did the import plan say 0 to change (no
drift), while importing a hand-made container often forces a replace? What does
that tell you about the relationship between the resource you write and the
object you adopt? And finally: why are the moved/removed/import blocks preferable
to the tofu state mv/rm commands, though they do similar things — what does a
plan give you that a hand command does not?
