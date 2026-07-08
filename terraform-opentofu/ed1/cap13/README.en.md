# Chapter 13 — The fire doors

**Level:** Intermediate
**Estimated time:** 50–60 minutes
**Manual topics:** the state monolith problem (13.1), what the blast radius is (13.2), how to segregate: the cut lines (13.3), making states talk: terraform_remote_state (13.4), pulling Part 3's threads (13.5)

## The idea

A building without fire doors burns all at once. A project with a single
state does too: in this exercise you first build the *monolith* — network
and application in the same notebook — and measure the blast radius: the
network team renames its own network, and the plan shows the fire
spreading all the way to the app's container; meanwhile, a single lock
queues everyone, whatever they are working on.

Then you install the fire doors: two configurations, two notebooks (in
the Consul you know from chapter 12), and the official channel to make
them talk — terraform_remote_state, the data source that reads another
state's *outputs*. You close with the two containment proofs: the most
destructive command in existence, launched in the app's room, cannot even
see the network; and a slow app apply no longer blocks the network's plan
— two queues, two locks, two teams genuinely working in parallel.

## Goals

By the end you will be able to:

- explain the monolith problem: blast radius, single lock, ever slower
  plans;
- recognise the classic cut lines (by component, by environment) and the
  criterion for choosing them;
- make two states talk with terraform_remote_state, and say why the
  channel is the *outputs* (a contract, not free access);
- demonstrate containment: destroy-scope limited to the room, independent
  locks;
- pull Part 3's threads together: resources, data, state — who does what.

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md.
- Docker running. Free port: 8500 (Consul, as in chapter 12).
- Chapters 10 (data sources), 11 (state) and 12 (backends and locks):
  this chapter uses all three.

## Your task

### Phase 0 — The monolith (and its radius)

Switch on the noticeboard (chapter 12's Consul):

    docker run -d --name cap13-consul -p 127.0.0.1:8500:8500 \
      hashicorp/consul:1.20 agent -dev -client=0.0.0.0

In start/monolith/ you will find the building without doors: the network
team's network and the app team's container, *in the same file, in the
same state*. Apply it:

    cd start/monolith
    tofu init
    tofu apply

Now play the network team: in main.tf rename the network from
cap13-core-net to cap13-core-net-v2, and ask for the plan:

    tofu plan

Read the fire: docker_network.core must be replaced — and, one line
below, docker_container.app must be replaced. The network team touched
*its own* resource, and the plan burns the app's too: a graph dependency,
same state, same plan, same lock — whoever works here queues everyone
else (chapter 12), and every mistake has *the whole notebook* as its
maximum radius. Undo the change and demolish the monolith:

    tofu destroy

(Demolish-and-rebuild is the lab's way: chapter 18 will teach you to make
this cut *without* demolishing, moving resources between states live.)

### Phase 1 — The cut

In start/ the two rooms are already laid out: network/ and app/. The
network room is complete: the same network as before, plus an *output* —
network_name. Look at it carefully: it is the room's official door, the
only thing the outside world will ever see. Apply:

    cd ../network
    tofu init
    tofu apply

Note the backend paths: book-labs/cap13/network and (shortly)
book-labs/cap13/app — two different keys on the same noticeboard: two
notebooks. Real-world cut lines follow two axes: by *component* (network
/ data / application — what you are doing) and by *environment* (dev /
staging / prod — never one notebook for all).

### Phase 2 — The intercom between rooms (TODOs 1 and 2)

In the app room, TODO 1 asks you for the data source that reads the other
notebook:

    data "terraform_remote_state" "network" {
      backend = "consul"
      config = {
        address = "127.0.0.1:8500"
        scheme  = "http"
        path    = "book-labs/cap13/network"
      }
    }

And TODO 2 puts it to work in the container:

    networks_advanced {
      name = data.terraform_remote_state.network.outputs.network_name
    }

Pause on the word outputs: remote_state does not give you access to the
other state's *resources* — only to its outputs. It is a contract: the
network team decides what to expose (network_name), and everything else
in its notebook remains its own business. Apply:

    cd ../app
    tofu init
    tofu plan
    tofu apply

In the plan, note chapter 10 at work: Reading... Read complete, and the
network's name already resolved — the other state exists, it is consulted
at plan time.

### Phase 3 — The two containment proofs

Proof one: the worst command, in the right room.

    tofu plan -destroy

Two resources: the container and the image. The network *does not
appear*: it is not in this notebook, and no command launched from this
room can touch it. The explosion's maximum radius is the room itself.

Proof two: two queues, two locks. TODO 3 adds the slow work to the app
(a 15-second time_sleep, chapter 12's trick). Then:

    tofu apply        # in the app: starts and stays busy

and while it runs, from the network room:

    tofu plan

No changes — *it passes immediately*. In chapter 12 this plan would have
been left outside the door with the lock error; now there are two locks,
one per notebook: the network team works while the app applies. The
monolith queued everyone; the fire doors give each team its room *and its
queue*.

### Phase 4 — Part 3's threads (reflect)

Five chapters, one system: resources impose (9), data consults (10), the
state binds code to reality and keeps too much (11), the backend gives it
a shared home with a lock (12), segregation gives it boundaries that
contain mistakes (13). Question c asks you to put them back together.

### Cleanup

Two rooms, two destroys — in the right order (consumers before
providers):

    tofu destroy                  # in the app room
    cd ../network && tofu destroy
    docker rm -f cap13-consul

## Definition of done

- In the monolith, renaming the network produced a plan with TWO replaces
  (network and container).
- The app's plan showed the remote_state read (Read complete) and the
  network name already resolved.
- tofu plan -destroy in the app room listed only container and image.
- The network's plan passed (No changes) WHILE the app's slow apply was
  running.
- You answered the three questions in answers.md.

## The three questions

**a.** The monolith: list the three costs you observed or deduced (plan
radius, single lock, and what would happen to plan times with 500
resources). In the fire's plan: why did the container burn *together*
with the network — which Part 1 chapter explains it?

**b.** The intercom: why does terraform_remote_state expose only the
outputs and not the other state's resources? Reason in terms of a
contract between teams: what can the network team change without telling
anyone, and what is a promise instead? And the flip side: what does the
radius NOT contain (if the network team really demolishes the network,
what happens to your app)?

**c.** Part 3's threads: compose in five sentences the state's journey —
from the file next to the code (11) to the shared home (12) to the
separate rooms (13) — and close with the cut line you would choose for a
real project with dev and prod, two teams and a database: how many
notebooks, and why?
