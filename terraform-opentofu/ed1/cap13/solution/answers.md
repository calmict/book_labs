# Chapter 13 — Answers (model solution)

## The fire (Phase 0)

    # docker_container.app must be replaced
    # docker_network.core must be replaced

## The intercom (Phase 2)

    data.terraform_remote_state.network: Reading...
    data.terraform_remote_state.network: Read complete after 0s
    + name = "cap13-core-net"        (already resolved, in the plan)

## The containment proofs (Phase 3)

    # proof 1:
    Plan: 0 to add, 0 to change, 3 to destroy.
    # (container, image, slow_work — the network does NOT appear)

    # proof 2:
    No changes. Your infrastructure matches the configuration.
    # (answered immediately, while the app's apply held its own lock)

## The three questions

**a. The monolith's costs.**

First cost, the radius: any plan in the monolith evaluates and can touch
EVERYTHING — the network team's rename produced a replacement of the
app's container too, because chapter 4's graph propagates the change
along the reference edge (name flows into networks_advanced), and in one
state the whole graph is one blast zone. Second cost, the lock: chapter
12's lock protects the whole notebook, so one team's apply queues every
other team — even for unrelated work. Third cost, time: every plan
refreshes every resource in the state; at 500 resources each little
change pays the full inventory's price. The container burned with the
network because of Part 1's chapter 3-and-4 combination: a ForceNew
attribute changed upstream, and the dependency edge dragged the
replacement downstream.

**b. The intercom as a contract.**

remote_state exposes only outputs because outputs are the room's declared
interface: the network team PROMISES network_name, and consumers build on
that promise alone. Everything else — resource names, addresses, how many
resources, their attributes — stays private: the team can refactor,
rename resources, split files, change implementation freely, and no
consumer breaks, as long as the output keeps its name and meaning. That
asymmetry is exactly what a contract between teams needs: a small,
stable, deliberate surface. The flip side: the radius contained is
OPERATIONAL, not physical. If the network team really destroys the
network, my app's container loses its network in reality — segregation
protects the notebooks (no command of mine can touch their state, no
mistake of theirs can corrupt mine), but runtime dependencies still
exist: the contract tells you WHO to call, not that you cannot be hurt.

**c. Part 3's threads, and my own cut.**

The state was born as a private file next to the code (11), where it
bound addresses to reality and kept every secret in plain text; the
backend gave it a shared home with access rules and a lock, turning two
colliding memories into one queue (12); segregation split that home into
rooms, so each team has its own notebook, its own lock, and mistakes stop
at the fire door (13); data sources (10) and remote_state give the rooms
a read-only intercom made of promised outputs; and resources (9) remain
the only hands that actually shape reality. For dev + prod, two teams and
a database: SIX notebooks — environment times component (dev/prod ×
network, database, app) — because environments must never share a blast
radius (a dev mistake must not be able to queue, corrupt or destroy
prod), and the database deserves its own room in each environment: it is
the component where prevent_destroy lives and where the replace radius
hurts most.
