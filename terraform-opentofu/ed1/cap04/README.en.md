# Chapter 4 — The invisible foreman

**Level:** Foundational
**Estimated time:** 35–45 minutes
**Manual topics:** what a directed acyclic graph is (4.1), how Terraform builds the graph (4.2), implicit and explicit dependencies (4.3), parallelisation (4.4), visualising the graph with terraform graph (4.5), the forbidden cycle: «Cycle detected» (4.6), what we take home from Part 1 (4.7)

## The idea

Across the last three chapters one question stayed open: when resources are
many and linked, who decides *in which order* to build them? Not you — you
never wrote an order anywhere. An invisible foreman decides: the dependency
graph, which the tool builds by reading your code.

In this exercise you make it visible with the most honest instrument there
is: a stopwatch. You build three floors of 5 seconds each *without telling
the model they are a tower*: they all go up together, 5 seconds total —
physically absurd, but the model does not know one floor rests on another
until the code says so. Then you chain the floors with references and look
at the stopwatch again: 15 seconds, one at a time. Same three resources, no
"order" written anywhere: only edges born from references. Finally you look
the graph in the face with tofu graph, watch the demolition proceed
backwards, and try to build the one thing the foreman refuses: the cycle —
the chicken born from the egg that is laid by the chicken.

## Goals

By the end you will be able to:

- explain where the graph's edges come from: the reference is the edge
  (implicit dependency), depends_on is the hand-declared edge (explicit);
- measure parallelisation: why what is unlinked travels together, and what
  is linked waits;
- read the output of tofu graph and find your own edges;
- predict the demolition order: the same graph, walked backwards;
- recognise the forbidden cycle and explain why it is rejected *before*
  touching reality.

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md. The commands use tofu;
  with terraform they are identical.
- No Docker this time: the time and local providers are enough (init
  downloads them).

## Your task

### Phase 0 — The floating tower

Open start/main.tf: three floors, each with a construction time of 5
seconds (a time_sleep resource: the "work" is sleeping, which makes the site
easy to time). Note that no floor mentions any other. Apply, timing it:

    cd start
    tofu init
    time tofu apply -auto-approve

Look at the real time: about 5 seconds, not 15. The three floors went up
*together* — a tower whose floors are built in parallel is a physical
absurdity, but nowhere does the model contain the information that floor_2
rests on floor_1. No edges, no waiting: the foreman sent three crews in
parallel, which was the right call *given the graph he had*.

### Phase 1 — Chaining the floors (implicit dependencies)

TODO 1 asks you to tell the model what physics already knows: each floor
rests on the previous one. You will not write "first... then...": you will
put into floor_2's triggers a *reference* to floor_1 (and into floor_3 one
to floor_2). The reference is everything: wherever a value flows from one
resource to another, there the graph has an edge.

Then demolish and rebuild, stopwatch in hand:

    tofu destroy -auto-approve
    time tofu apply -auto-approve

Now about 15 seconds: one floor at a time. Same three resources, same code
apart from two lines of reference — but the graph changed, and the order
with it. The apply also narrated it live: look at the sequence of
Creating/Creation complete lines in the output.

### Phase 2 — The occupancy certificate (explicit dependency)

TODO 2 adds the certificate of occupancy: a file that must be born only when
the tower is finished. But its content uses *no* attribute of the floors: no
value flows, so no reference — and without a reference, no edge. This is the
(rare) case where you declare the edge by hand:

    depends_on = [time_sleep.floor_3]

Apply and watch the certificate appear last. Rule of thumb: a reference when
a value is truly needed, depends_on only when the dependency is real but
invisible to the data.

### Phase 3 — Looking the graph in the face

So far you inferred the graph from the stopwatch. Now look at it:

    tofu graph | grep ' -> '

Among the service edges (provider, root) you will find yours:
floor_2 -> floor_1, floor_3 -> floor_2, certificate -> floor_3. Read the
arrow as "depends on": it always points at what must exist first. (If you
have graphviz, try: tofu graph | dot -Tsvg > graph.svg — not needed for the
exercise.)

### Phase 4 — The demolition, backwards

    tofu destroy

Before confirming, look at the plan; then, as it demolishes, watch the order
of the Destroying lines: floor_3 first, floor_1 last, the certificate before
everything. It is the same graph, walked backwards — nobody demolishes the
ground floor with the third floor still on top. It is the reason why in
chapter 3 the image was created before the container, but destroyed after
it.

### Phase 5 — The forbidden cycle

In start/cycle/ you will find a model that is complete but broken by design:
the chicken is born from the egg, the egg is laid by the chicken. Each
references the other: two edges biting their own tail.

    cd cycle
    tofu init
    tofu validate

Error: Cycle: local_file.chicken, local_file.egg. Pause on two details.
First, the *why*: the foreman must find someone who can start first, and in
a cycle no such node exists — every node waits for another node of the
cycle. This is why the graph must be acyclic: it is not pedantry, it is the
very existence of an execution order. Second, the *when*: validate told you,
without touching anything — the graph is built from code alone, so the flaw
is found before any contact with reality.

### Cleanup

Go back to start/ (the cycle never created anything) and, if you have not
already:

    tofu destroy

## Definition of done

- The Phase 0 apply took about 5 seconds; the Phase 1 apply about 15 (you
  measured both with time).
- In tofu graph you spotted your three edges: floor_2 -> floor_1,
  floor_3 -> floor_2, certificate -> floor_3.
- During demolition the order was reversed: certificate and floor_3 first,
  floor_1 last.
- tofu validate in cycle/ fails with Error: Cycle and the names of the two
  resources.
- You answered the three questions in answers.md.

## The three questions

**a.** Where did each edge of your graph come from, one by one? You never
wrote "this first, then that": what created the edges for you, and in which
direction do the arrows of tofu graph point? And when is depends_on the
right call instead of a reference?

**b.** The stopwatch: 5 seconds versus 15, with the same three 5-second
resources. Explain both measurements in terms of the graph. Then the cycle:
why does a graph with a cycle admit *no* execution order at all, and what
does it tell you that the error comes from validate, before touching
reality?

**c.** The complete thread of Part 1: drift (ch. 1), convergence (ch. 2),
immutability (ch. 3), the graph (ch. 4). Compose the picture in a few
lines: what journey does your main.tf make from the moment you describe the
result to the moment reality resembles it? And why is reverse-order
demolition not a courtesy but a necessity (think of chapter 3's image and
container)?
