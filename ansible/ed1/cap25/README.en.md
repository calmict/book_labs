# Chapter 25 — The right tempo

**Level:** Cloud Architect

Until now you have orchestrated a handful of nodes, and with a handful every playbook feels fast. But
the Cloud Architect tier opens with a different question: what happens when the nodes become a
**thousand**? At that scale one extra second per host is not a second — it is an endless wait,
multiplied by a thousand, repeated on every deploy. The bottleneck is no longer *what* the playbook
does, but *how* Ansible spreads it across the fleet. This chapter gives you the levers to tighten that
time: how many nodes to drive at once (**forks**), whether to march them in lock-step or let them race
(**strategies**), and how not to pay for work nobody needs (**taming facts**). You measure them on a
real fleet — twelve nodes — and watch them bite: the same rollout drops from ~24 seconds to ~8.

## Objectives

- Why at **scale** the problem changes nature: not the task, but the distribution (25.1).
- **forks**: how many nodes Ansible drives in parallel, and why "in waves" costs (25.2).
- **Strategies** — linear vs free: the per-task barrier and how to remove it (25.3).
- **Pipelining** and ControlPersist: fewer SSH round trips per task (25.4).
- **Taming facts**: gather_facts off, gather_subset, fact caching (25.5).
- **Mitogen**: the strategy plugin that rewrites execution — powerful and a commitment (25.6).
- **Measure, don't guess**: the profile_tasks callback (25.7).

## Prerequisites

- The chapter 6 venv with **ansible-core** (in start/requirements.txt): nothing else — the fleet is
  made of local hosts.
- The chapter 7 **ansible.cfg** (this is where one of the three levers lives) and **strategies** as a
  concept: you brushed against them with the parallelism of chapter 9.
- The **facts** of chapter 2 and the **variables** of chapter 12: here you decide *when* it is worth
  gathering them.

## The scenario

start/ contains a rollout that *works* but is needlessly slow. inventory.ini describes a **fleet of
12 nodes**, all local (ansible_connection=local, so the exercise costs nothing), but each with a
different load: t1 and t2 are the seconds the rollout's two steps take on that node. The imbalance is
the point — some nodes are quick, some slow, and a slow node must not hold the quick ones hostage.

deploy.yml runs two steps (a "sleep" stands in for per-host work) across the fleet. As it stands it
runs in waves, in lock-step, and gathers facts nobody uses. Three gaps slow it down; you close them
and measure the gain.

Set up the environment:

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    cd start

### Phase 1 — The problem changes nature (25.1)

With three nodes you notice nothing. With a thousand, the arithmetic dominates. If Ansible drives the
nodes in waves, the total time is not the slowest node's: it is the slowest node **times the number of
waves**. If every play waits for all nodes to finish a task before any node starts the next, the quick
nodes stand idle at every step. If every play gathers facts it never looks at, you pay a round of
setup on a thousand nodes for nothing. None of these costs shows at small scale; all become dominant
at large scale. This chapter's levers remove these wastes one by one. First measure the baseline:

    time ansible-playbook deploy.yml

Keep the number in mind: it is the yardstick against which you measure every improvement.

### Phase 2 — forks (25.2 — TODO 1)

forks is **how many nodes Ansible drives at the same time**. It does not make each node faster: it
decides in how many waves the fleet is served. Twelve nodes at forks=4 is three waves, and the run
cannot be shorter than the slowest node times the number of waves, however trivial the work. Open
start/ansible.cfg: forks is deliberately low. Complete **TODO 1** by raising it to the fleet size —

    [defaults]
    inventory = inventory.ini
    forks = 12

Now the waves collapse into one: the run is bounded by the single slowest node, not by fleet size. It
is the cheapest win at scale, the first lever to reach for. With one caution the manual stresses: each
fork is work, memory and an SSH connection on the **control node**, so on real fleets you raise forks
deliberately, not to infinity.

### Phase 3 — Strategies: linear vs free (25.3 — TODO 2)

The default strategy is **linear**, and linear installs a **barrier at every task**: no node starts
task N+1 until *every* node has finished task N. On a fleet with uneven loads that means the quick
nodes stand idle at each barrier waiting for the slowest — and they pay that tax once per task. The
**free** strategy removes the barrier: each node runs down its own task list as fast as it can, and
the play ends when the last node is done. Complete **TODO 2** in deploy.yml —

    strategy: free

The gain grows with the imbalance and with the number of tasks — exactly the shape of a real rollout.
The trade-off, and the reason linear is the default, is that free gives up the lock-step guarantee:
with free you can no longer assume the whole fleet has cleared a step before any node moves past it.
When order matters — orchestrated rollouts — you need the control of chapter 27.

### Phase 4 — Pipelining (25.4)

The first two levers cut waiting; pipelining cuts the **number of SSH operations** per task. Without
it, a module is a copy of a file to the node followed by a separate execution: several round trips per
task. With pipelining Ansible feeds the module over the already-open connection — one round trip per
task. Combined with ControlPersist (the reused SSH connection of chapter 3) it is a large win on real
fleets. You enable it in ansible.cfg:

    [ssh_connection]
    pipelining = True

Two caveats: it needs **requiretty off** in the target's sudoers (otherwise sudo refuses the stdin),
and it does nothing for local connections — which is why this node-less fleet leaves it as reading and
measures forks, strategy and facts instead.

### Phase 5 — Taming facts (25.5 — TODO 3)

Every play, by default, gathers facts: before the first task Ansible runs an implicit **setup** on
each node — a full round trip — to learn its variables. Exactly right when you use those facts, pure
waste when you do not. This rollout references not a single one, so the whole gathering is cost with no
benefit. Complete **TODO 3** in deploy.yml —

    gather_facts: false

Re-run with profile_tasks (phase 7) and you will see the "Gathering Facts" line **vanish**. When a
later task *does* need a fact, you do not switch gathering back on for the whole fleet every run: you
**cache** it (fact caching) so the setup pays off once and is reused, or narrow it with gather_subset.
Off by default plus caching is the scalable choice; gather-everything-every-time is the habit to
unlearn.

### Phase 6 — Mitogen (25.6)

When the built-in levers are spent and it is not enough, there is **Mitogen**: a third-party strategy
plugin that rewrites how Ansible ships and runs code on the target, often several times faster. It is
genuinely powerful and genuinely a bigger commitment: an external dependency, tied to specific Ansible
versions, that changes execution semantics. The manual presents it as the deliberate, measured last
resort, after this chapter's levers have been spent — not as a first move.

### Phase 7 — Measure, don't guess (25.7)

All of this is decided on numbers, not on feel. **profile_tasks** is a built-in callback that, once
enabled, prints how much each task cost: read which tasks actually weigh, then tune those.

    ANSIBLE_CALLBACKS_ENABLED=profile_tasks ansible-playbook deploy.yml

Compare the baseline profile with the tuned one: the "Gathering Facts" line is in the first and gone
from the second, and the two steps no longer sum in lock-step. Question a.

## Done when

- ansible.cfg carries **forks = 12** (TODO 1): the fleet runs in a single wave.
- deploy.yml uses **strategy: free** (TODO 2): no per-task barrier.
- deploy.yml uses **gather_facts: false** (TODO 3): no useless setup.
- The tuned rollout is **clearly faster** than the starting one (here ~8s vs ~24s) and profile_tasks
  confirms it: fact gathering is gone, and the steps no longer march in lock-step.

## Reflection questions

**a.** forks, strategy and facts attack three different wastes. Describe, for each, *which* wait it
removes — and why none of the three shows at three nodes but all dominate at a thousand. If you could
touch **only one** on a fleet with very uneven loads, which would you choose and why?

**b.** free is faster than linear but gives up lock-step. Describe a rollout where that surrender is
**dangerous** — where you need the guarantee that the whole fleet has cleared a step before any node
moves past it. (Chapter 27 builds exactly that control.)

**c.** gather_facts: false is pure gain here because the rollout uses no facts. But a later task might
need one. Why is the scalable answer **fact caching** and not "switch gathering back on every run"?
What changes, in cost terms, between paying the setup once and paying it every time across a thousand
nodes?

## Cleanup

Nothing to tear down: the fleet is local hosts, with no containers or remote nodes. Close the venv
with:

    deactivate

## Where it leads

You have the levers to serve a thousand nodes fast (ch. 25). But speed alone is not enough to ship to
production with confidence: every change needs to pass through **version control** and a **pipeline**
that validates it before it touches a server. **Chapter 26** takes automation into **CI/CD** — GitHub
Actions, the production gate — because at this scale it is no longer a person who launches the
playbook: it is the pipeline.
