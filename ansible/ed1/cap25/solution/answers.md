# Chapter 25 - Answers (model solution)

## The three TODOs

    # TODO 1 (25.2) - ansible.cfg: drive the whole fleet in one wave
    [defaults]
    inventory = inventory.ini
    forks = 12

    # TODO 2 (25.3) - deploy.yml: drop the per-task barrier
    strategy: free

    # TODO 3 (25.5) - deploy.yml: stop gathering facts nobody uses
    gather_facts: false

solution/run.sh proves it. It times the tuned rollout against the starting one on the same 12-node
fleet, with the profile_tasks callback on both. Measured here: the tuned rollout finishes in about
8 seconds against about 24 for the starting one - roughly three times faster - and run.sh asserts a
margin of at least 1.5x so it never passes by luck. The same run shows a "Gathering Facts" line in
the starting profile that is simply gone from the tuned one, and it re-reads the solution files to
confirm all three levers are actually set.

## Why each lever matters

**forks (25.2).** forks is how many nodes Ansible drives at the same time. Low forks does not make
each node slower - it makes Ansible attend to the fleet in waves. Twelve nodes at forks=4 is three
waves; the run cannot be shorter than the slowest node times the number of waves, no matter how
trivial the work. Raising forks to the fleet size collapses the waves into one, so the run is bounded
by the single slowest node instead of by fleet size. This is the cheapest win at scale and the first
knob to reach for, with one caution the manual makes: forks is load on the control node (each fork is
work, memory and an SSH connection), so on real fleets you raise it deliberately, not to infinity.

**strategy: free (25.3).** The default strategy is linear, and linear installs a barrier at every
task: no node begins task N+1 until every node has finished task N. On a fleet with uneven work that
means the quick nodes stand idle at each barrier waiting for the slowest, and they pay that tax once
per task. The free strategy removes the barrier: each node runs straight down its own task list as
fast as it can, and the play ends when the last node is done. The gain grows with imbalance and with
the number of tasks - exactly the shape of a real rollout. The trade-off, and the reason linear is
the default, is that free gives up the lock-step guarantee: with free you can no longer assume the
whole fleet has cleared a step before any node moves past it, which matters for orchestrated,
order-sensitive rollouts (the subject of chapter 27).

**gather_facts: false (25.5).** Every play gathers facts by default: before the first task Ansible
runs an implicit setup on each node - a full round trip and a chunk of work - to learn its variables.
That is exactly right when you use those facts and pure waste when you do not. This rollout references
none, so the whole gathering phase is cost with no benefit, and turning it off deletes it outright:
profile_tasks shows the "Gathering Facts" line vanish. When a later task does need a fact, you do not
switch gathering back on for the whole fleet every run - you cache facts (fact caching, 25.5) so the
setup pays off once and is reused, or gather on demand. Off-by-default plus caching is the scalable
default; gather-everything-every-time is the one to unlearn.

## Two levers this chapter names but the lab leaves as prose

**Pipelining (25.4)** cuts the number of SSH operations per task. Without it, a module is a copy of a
file to the node followed by a separate execution; pipelining feeds the module over the already-open
connection instead, so each task is one round trip rather than several. Combined with ControlPersist
(the reused SSH connection from chapter 3) it is a large real-fleet win - but it needs requiretty off
in sudoers, and it does nothing for local connections, which is why this node-less lab measures forks,
strategy and facts instead and leaves pipelining as reading.

**Mitogen (25.6)** is a third-party strategy plugin that rewrites how Ansible ships and runs code on
the target, often several times faster. It is genuinely powerful and genuinely a bigger commitment: an
external dependency, tied to specific Ansible versions, that changes execution semantics - so the
manual presents it as the deliberate, measured last resort, after the built-in levers here have been
spent. profile_tasks (25.7), the built-in callback this lab uses, is how you decide any of this on
evidence rather than on hunch: enable it, read which tasks actually cost time, then tune those.
