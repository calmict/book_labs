# Chapter 3 — Renovate or rebuild

**Level:** Foundational
**Estimated time:** 40–50 minutes
**Manual topics:** what «immutable» means (3.1), the two roads of change: in-place and replace (3.2), governing the replacement: the lifecycle block (3.3), why immutability reduces risk (3.4), the thread binding Part 1 (3.5)

## The idea

Facing a building that must change, the architect has two roads: renovate
(the building stays up, one system gets changed) or demolish and rebuild (a
new building takes the old one's place). Infrastructure works the same way,
and the remarkable thing is that *you do not decide* which road is taken:
the provider knows it, attribute by attribute — and the plan always
announces it in advance, with precise signage that this exercise teaches you
to read.

Here the "server" is for the first time a living thing: a Docker container
running nginx. You change its memory and watch it remain the same object
(renovation, in-place). Then you change the image version and watch it *die
and be reborn* (reconstruction, replace): nobody ever stepped inside that
container to upgrade nginx — this is, literally, immutability. Finally you
take the lifecycle block in hand and govern the replacement: first you flip
the order (build the new one, then demolish the old one), then you engage
the safety catch that blocks any demolition — and discover it blocks more
than you thought.

## Goals

By the end you will be able to:

- read in the plan which road was chosen: the tilde of the in-place update,
  the -/+ of the replace, the marker that says exactly *which* attribute
  forces the replacement;
- explain why the provider decides the road, attribute by attribute;
- flip the replacement order with create_before_destroy, and state which
  condition on identity makes it possible;
- use prevent_destroy as a safety catch, knowing it blocks replacements too;
- tie drift (ch. 1), convergence (ch. 2) and immutability into one thread.

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md.
- Docker running and usable by your user (docker version must answer): this
  is the first exercise using the docker provider.
- The exercise downloads three small nginx alpine images (~20 MB each).

## Your task

### Phase 0 — The first building

Open start/main.tf: there is an nginx image at a pinned version and a
container using it, with a detail to note right away: *the container's name
contains the version*. It looks cosmetic — it becomes decisive in Phase 3.

    cd start
    tofu init
    tofu apply
    docker exec cap03-web-1-25-alpine nginx -v

Your building is up, and states its version: nginx 1.25.

### Phase 1 — The renovation (in-place)

Note down the building's identity:

    docker inspect -f '{{.Id}}' cap03-web-1-25-alpine

In main.tf bring the memory from 128 to 256. Then, before applying, read:

    tofu plan

Look for two things: the title line — will be updated **in-place** — and the
tilde (~) in front of memory. This is the renovation signage: the object
will remain the same, one system will change. Apply and verify:

    tofu apply
    docker inspect -f '{{.Id}}' cap03-web-1-25-alpine

The very same ID: no demolition. Under the hood the provider did the
equivalent of a docker update on the living container.

### Phase 2 — The reconstruction (replace)

Now change the version: in main.tf bring nginx_version to 1.26-alpine. And
again, before applying:

    tofu plan

The signage changed completely: the title says **must be replaced**, the
resource carries -/+ and, line by line, the plan marks with
"# forces replacement" *exactly which* attributes cannot change on a living
object. Note also the announced order: destroy and then create replacement —
demolition first, construction after. Apply:

    tofu apply
    docker exec cap03-web-1-26-alpine nginx -v
    docker ps -a

nginx 1.26, and no trace of the old container. Pause on what did NOT happen:
nobody entered the container to run an upgrade. The building with nginx 1.25
inside no longer exists; a new one exists, cast from a new image. This is
the concrete meaning of «immutable»: change does not pass through the
object, it replaces it.

### Phase 3 — Flipping the order (create_before_destroy)

The default order — demolish, then rebuild — has a hole: between the two
there is a moment when the building does not exist. TODO 1 in main.tf asks
you to add to the container the lifecycle block with create_before_destroy.
Then bring the version to 1.27-alpine and read the plan:

    tofu plan

The symbol became +/- and the title says: create replacement **and then**
destroy. The new one first, the old one's demolition after. Apply.

And now the important question: why did it work? Because the two containers
— alive together for an instant — *share nothing of their identity*: the
name contains the version, so the new one never conflicts with the old one.
Had the name been fixed, building the new one would have failed on the
already-taken name. This is the general rule of create_before_destroy: it
only works if identity is not a single contended piece.

### Phase 4 — The safety catch (prevent_destroy)

TODO 2 asks you to add prevent_destroy to the lifecycle block. Then try to
raze everything:

    tofu destroy

Error: Instance cannot be destroyed. The catch works. But now try instead to
change the image version once more in main.tf, and ask only for the plan:

    tofu plan

Same error. Re-read Phase 2 and come back: a replace *is* a destroy (plus a
create) — so the catch also blocks version upgrades. It is exactly what you
want on a production database, and exactly what you must remember the day an
innocent parameter change refuses to start.

### Cleanup

Remove the prevent_destroy line (the catch is switched off deliberately, in
code: this too is a trait of the declarative model), bring the version back
to 1.27-alpine if you had changed it, then:

    tofu destroy

The downloaded nginx images stay on your disk (keep_locally: spares you the
re-pull if you redo the exercise); remove them with docker rmi if you want.

## Definition of done

- After Phase 1 the container ID is identical to before the apply (you
  verified it with docker inspect).
- In the Phase 2 plan you spotted the "# forces replacement" marker and the
  destroy and then create replacement announcement.
- In the Phase 3 plan the order is flipped: create replacement and then
  destroy.
- In Phase 4 both the destroy and the version-bump plan fail with Instance
  cannot be destroyed.
- You answered the three questions in answers.md.

## The three questions

**a.** The two roads of change: which attribute travelled in-place and which
forced the replacement? How did you know *before* applying — which plan
signage announced it? And why is the road decided by the provider, attribute
by attribute, and not by you?

**b.** With create_before_destroy the order flipped. What made it possible
in this exercise (think about the container's name), and what would have
happened with a fixed name? Then prevent_destroy: what does it protect you
from, what did it surprise you by blocking, and what does it NOT protect you
from at all (think of someone deleting by hand, outside the model)?

**c.** The thread of Part 1: chapter 1 showed you drift, chapter 2
convergence, this chapter replacement instead of repair. Why does rebuilding
reduce risk compared to renovating (think of the history the snowflake
accumulates, and of what it takes to roll back after a bad upgrade)? And
what is still missing from the picture — how does the tool know *in which
order* to build and demolish several linked resources? (That is chapter 4.)
