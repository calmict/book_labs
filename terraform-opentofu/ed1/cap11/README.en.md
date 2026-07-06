# Chapter 11 — The notebook and its secrets

**Level:** Intermediate
**Estimated time:** 45–55 minutes
**Manual topics:** the problem state solves (11.1), the three sources of truth (11.2), inside the state file (11.3), the state contains sensitive data (11.4), why shared state changes everything (11.5), recap and bridge (11.6)

## The idea

For ten chapters you have used plan and apply, and one character has been
working in the shadows at every command: the notebook where the tool
records what it built and what it was called in the code. In this chapter
you open it and read it: terraform.tfstate, the mapping between the
model's addresses and the real objects — with even the graph's edges
inside.

Then three discoveries, in crescendo. The first one burns: you create a
password marked sensitive, the output hides it — and the notebook keeps it
*in plain text*: whoever reads the state reads every secret. The second is
the game of the three sources of truth: code, memory, reality — you delete
a container behind the model's back and learn the command that syncs *only
the memory* (plan and apply -refresh-only), separating "update the
notebook" from "touch the world". The third is the finale that sets up
chapter 12: a colleague clones your code but not your memory — his plan
wants to rebuild everything, his apply crashes into the reality that
already exists, and his notebook is left half-written. Same code, two
memories, one reality: it is the problem that only *shared* state solves.

## Goals

By the end you will be able to:

- explain which problem the state solves: the code-address ↔ real-object
  binding that neither the code nor reality contains;
- find your way inside terraform.tfstate: version, serial, lineage,
  resources, attributes, dependencies;
- demonstrate that sensitive protects the *output*, not the *state* — and
  draw the operational consequences;
- use plan/apply -refresh-only to realign the memory without touching
  reality;
- tell, with a concrete example, why two memories over the same world lead
  to collision.

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md. jq handy but optional
  (grep works too).
- Docker running. No port needed.
- Chapters 1–2 (drift, convergence) and 10 (the bridge that brought you
  here).

## Your task

### Phase 0 — A small world with a secret

In start/main.tf you will find three resources: a random_password (the
database secret, marked sensitive), the nginx image and a container. No
writing TODO this time: this chapter's work is *reading* — the notebook,
the plans, the errors.

    cd start
    tofu init
    tofu apply
    tofu output

The output is already the first lesson: db_password = <sensitive>.
Apparent confidentiality — we dismantle it in a minute.

### Phase 1 — Inside the notebook

The file is right there, next to the code: terraform.tfstate. Open it:

    jq '.version, .serial, .lineage' terraform.tfstate
    jq '.resources[] | {type, name}' terraform.tfstate
    jq '.resources[] | select(.type=="docker_container") | .instances[0].attributes.id' terraform.tfstate

Get your bearings: version (the format), serial (grows at every write),
lineage (the identity of *this* memory, from birth), and resources — the
mapping that is the reason for everything: docker_container.web, address
in the code, bound to the container's real id. It is 11.1's problem,
solved: the code says "a container called web", reality contains a
thousand — *only the notebook* knows which one is yours. Look also for
the container's dependencies entry: the notebook remembers even the
graph's edges (the destroy needs them to demolish in reverse order even
if one day you deleted the block from the code).

### Phase 2 — The secret in plain text

The output said <sensitive>. Now ask the notebook:

    jq -r '.resources[] | select(.type=="random_password") | .instances[0].attributes.result' terraform.tfstate

There it is, in plain text. (Without jq: grep result
terraform.tfstate.) Note the refined paradox: in the same file there is
sensitive_attributes *marking* result as sensitive — the mark serves to
redact outputs and plans, but the value must live in the state by
necessity: without it, the tool could neither compare nor reuse it.
Non-negotiable consequences: the state is never committed (this repo's
.gitignore excludes it — and now you know why), it is protected like a
keyring (restricted access, encryption at rest: chapter 12's backends),
and OpenTofu holds one extra ace — native state encryption — which is one
of chapter 20's reasons.

### Phase 3 — The three sources of truth

Code, memory, reality. Make them diverge: delete the container behind the
model's back (chapter 1's drift, demolition edition):

    docker rm -f cap11-web
    tofu plan -refresh-only

Read the header carefully: Objects have changed outside of OpenTofu —
docker_container.web has been deleted. The -refresh-only is the plan *of
the memory alone*: it compares notebook and reality, ignores the code,
and proposes to build nothing — only to take note. Accept:

    tofu apply -refresh-only
    tofu state list

The container is gone from the memory (the other two resources remain).
Note that reality was not touched: you only updated the notebook. Now
bring the third source back into play:

    tofu plan

1 to add: code (wants it) against updated memory (knows it is gone).
Apply and the world is whole again. The full cycle, spelled out: refresh
aligns memory↔reality, plan compares code↔memory, apply bends reality to
the code.

### Phase 4 — The colleague with the empty notebook

A colleague clones your project. The code travels in git; the state does
not (Phase 2 taught you why). Simulate it:

    mkdir ../colleague
    cp main.tf ../colleague/
    cd ../colleague
    tofu init
    tofu plan

Plan: 3 to add. Read it again: his plan wants to create *everything* —
password, image, container. He has not gone mad: his memory is empty, and
to him your objects simply do not exist. Now let him apply:

    tofu apply

Error: Conflict. The container name "/cap11-web" is already in use.
Reality is one, and your container occupied it. And look at his notebook
after the crash:

    tofu state list

Password and image are there (created before the collision): memory half
written, world contested, two "owners" of the same name. This is 11.5's
problem in miniature: *separate state does not scale past one person*.
The solution is not discipline — it is ONE notebook, shared, with a lock:
remote backends, chapter 12.

### Cleanup

Two notebooks, two destroys:

    tofu destroy          # in the colleague folder
    cd ../start
    tofu destroy

## Definition of done

- You can point at, inside the tfstate: serial, lineage, the
  docker_container.web → real id mapping, and the dependencies entry.
- You saw the same password <sensitive> in the output and in plain text
  in the state.
- The plan -refresh-only showed "has been deleted" and the apply
  -refresh-only updated ONLY the memory (state list without the
  container, reality untouched).
- The colleague: "3 to add" plan, apply failed with Conflict, partial
  state list (password and image).
- You answered the three questions in answers.md.

## The three questions

**a.** 11.1's problem: the code says "a container called web", reality
contains many — what does the notebook know that neither the code nor
reality contains? And why does the notebook record dependencies too, if
the graph can be rebuilt from the code? (Think of a block deleted from
the code before a destroy.)

**b.** The secret: why MUST the password's value live in the state, if
sensitive hides it elsewhere? List the operational consequences (git,
access, encryption) and explain what -refresh-only adds to your toolbox:
in which situations do you want to update the memory *without* touching
the world?

**c.** The colleague: reconstruct the incident with the three sources of
truth (what his code said, his memory, reality) and explain why no
chat-based coordination discipline can replace a shared notebook. What
must chapter 12's "single notebook" guarantee, at minimum, for two
colleagues to work without stepping on each other? (Think also about what
the lock is for.)
