# Chapter 4 — Answers (model solution)

## The stopwatch (Phases 0 and 1)

    # real time of the Phase 0 apply (no edges):   ~5s
    # real time of the Phase 1 apply (chained):    ~15s

## Your edges in tofu graph (Phase 3)

    "[root] time_sleep.floor_2 (expand)" -> "[root] time_sleep.floor_1 (expand)"
    "[root] time_sleep.floor_3 (expand)" -> "[root] time_sleep.floor_2 (expand)"
    "[root] local_file.certificate (expand)" -> "[root] time_sleep.floor_3 (expand)"

## The demolition order (Phase 4)

    local_file.certificate: Destroying...
    time_sleep.floor_3: Destroying...
    time_sleep.floor_2: Destroying...
    time_sleep.floor_1: Destroying...

## The forbidden cycle (Phase 5)

    Error: Cycle: local_file.chicken, local_file.egg

## The three questions

**a. Where did each edge come from, which way do the arrows point, and when
is depends_on the right call?**

Two edges were born from references: floor_2's triggers contain the value
time_sleep.floor_1.id, so a value flows from floor_1 into floor_2 — and
wherever a value flows, the graph has an edge (the same for floor_3 on
floor_2). I never wrote an order: the expressions themselves are the
declaration of dependency, which is why implicit dependencies are the norm.
The third edge is explicit: the certificate uses no attribute of any floor,
no value flows, so no reference could exist — depends_on declares the edge
by hand. In tofu graph the arrow points from the dependent to its
dependency: X -> Y reads "X depends on Y", so Y must exist first. Rule of
thumb: reference when a value is truly needed (self-documenting and
impossible to forget), depends_on only for real dependencies invisible to
the data — hidden side effects, like a policy that must exist before a
service starts using it.

**b. Explain 5 seconds versus 15 in terms of the graph, and why a cycle
admits no execution order — caught before touching reality.**

With no edges the three floors are three disconnected nodes: nothing in the
graph says one must wait for another, so the foreman dispatches all crews
at once and the wall time is the longest single job — 5 seconds. With the
chain, each node has an incoming edge from the previous one: floor_2 cannot
start before floor_1 finishes, so the jobs serialise and the times add up —
15 seconds. Same resources, same durations: only the edges changed, and the
schedule with them. A cycle destroys the very possibility of a schedule:
to start chicken you need egg finished, to start egg you need chicken
finished — no node of the cycle can ever be first, so no execution order
exists at all. That is why the graph must be acyclic. And validate caught
it because the graph is built from the code alone: no state, no API call,
no reality needed — a structural flaw in the model is found while it is
still only a model.

**c. The complete thread of Part 1, and why reverse-order demolition is a
necessity.**

The journey: I describe the result, not the steps (ch. 2 — the photograph);
the tool compares model and reality and computes the minimal actions that
converge one into the other (ch. 2 again, killing ch. 1's drift); where a
change cannot pass through a living object, the object is replaced, not
repaired (ch. 3 — immutability); and the order in which all those actions
run is derived from the dependency graph my own references drew (ch. 4).
Nothing in that chain is a step I wrote: the model carries the what, the
graph carries the when. Reverse-order demolition is a necessity because the
edges state existence requirements: the container needs its image, the
certificate needs its tower. Creating walks the arrows from the pointed-to
to the pointing (image, then container); destroying must walk them the
other way (container, then image), or you would be removing something a
living resource still stands on — demolishing the ground floor with the
third floor still inhabited.
