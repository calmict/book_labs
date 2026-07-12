# Chapter 27 — Without stopping the music

**Level:** Cloud Architect

Chapter 26 gave you the stage machinery that carries a change to the door of production. But the deploy
job was one line of echo, and now the real question arrives: *how* do you update a fleet of a thousand
nodes **without taking the service down**? Applying to everyone at once is an outage — for a few
seconds or minutes, every backend is down at the same moment. A conductor does not stop the whole
orchestra to let one violinist change a string: they bring sections in and out one at a time, and the
music never stops. This is **orchestration**: the rolling update. This chapter gives you the levers —
**serial** (update in waves), **delegate_to** (tell the load balancer to take the node out of rotation
before you touch it), the **choreography** pre_tasks/tasks/post_tasks (drain → update → re-enable), and
**max_fail_percentage** (the emergency brake that stops everything if a wave goes bad) — and you watch
them at work on a web farm where, at every instant, no more than one wave is out of rotation.

## Objectives

- From **automation to orchestration**: why "apply to everyone" is no longer enough (27.1).
- The first lever: **serial** and wave releases (27.2).
- The second lever: **delegate_to** with the load balancer (27.3).
- The **full choreography**: pre_tasks, tasks, post_tasks (27.4).
- The **emergency brake**: max_fail_percentage (27.5).
- When something goes wrong: **rollback and recovery** (27.6).
- Coordinating **multiple tiers and groups** (27.7).
- **Good habits** with orchestration (27.8).

## Prerequisites

- The chapter 6 venv with **ansible-core** (in start/requirements.txt): nothing else — the fleet is
  local.
- **pre_tasks/post_tasks** and inventory **groups** (ch. 8, ch. 10): here they become the release
  choreography.
- The idea of **checking after a change** (ch. 14): a wave is validated before moving to the next.
- No cloud account and no remote node: the web farm and the load balancer are local hosts; the pool
  state is a file, so the rollout is visible.

## The scenario

start/ contains a wave release over a **web farm of 6 nodes** (group webfarm) behind a **load balancer**
(host balancer) — all local. The balancer's pool, normally invisible, is here a **ledger file**: every
time a node leaves rotation (DRAIN), is updated (UPDATED) or returns (ENABLE), the line lands in the
ledger, with a timestamp. So you can *see* the rollout as it happens — and the test can verify it. The
site.yml playbook does the choreography, but three gaps leave it dangerous: it updates everyone at
once, it forgets to put the nodes back in rotation, and it has no brake. You close them.

Set up the environment:

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    cd start

And, to watch the pool as it runs:

    : > /tmp/cap27-pool.log       # clear the ledger
    ansible-playbook site.yml
    cat /tmp/cap27-pool.log       # the waves, line by line

### Phase 1 — From automation to orchestration (27.1)

So far Ansible has answered "bring N nodes to the desired state". **Orchestration** adds a dimension:
*in what order, with which pauses, with which checks between one step and the next*. The difference is
between "update the six nodes" and "update two nodes, check they are healthy, then two more, then the
last two — and if a wave collapses, stop". The first is automation; the second keeps the service
standing while you change it. At a thousand nodes this is not a luxury: it is the only way to release
without a hole of downtime.

### Phase 2 — The first lever: serial and wave releases (27.2 — TODO 1)

By default Ansible applies a play to **all** the hosts of the group in parallel (up to the forks
limit). On a web farm that means every backend down at the same moment. **serial** breaks the play into
**waves**: Ansible runs the entire play — pre_tasks, tasks, post_tasks — for a small batch of hosts,
then moves to the next. Complete **TODO 1** on the play —

    serial: 2

With serial: 2 on a farm of 6, the release proceeds in **three waves** of two. At every instant at most
two nodes are out of rotation: capacity never drops below 6 − 2 = 4. serial also accepts a list
(serial: [1, 2, "50%"]) to do a small "canary" wave and then widen. The rule behind choosing serial:
how many nodes can you remove without dropping below peak capacity? That is your number. Question a.

### Phase 3 — The second lever: delegate_to with the load balancer (27.3)

Taking a node out of rotation is not an action you do **on the node**: you do it **on the load
balancer**, which is what routes traffic. But the play runs "on the web node" (that is where you
update). **delegate_to** solves exactly this: it runs a single task on a *different* host, keeping the
context of the current node. Look at the pre_task already written —

    - name: Take the host out of the pool
      ansible.builtin.shell: 'echo "... DRAIN {{ inventory_hostname }} ..." >> {{ ledger }}'
      delegate_to: "{{ lb_host }}"

The task is about inventory_hostname (the web node), but it **runs on the balancer** (lb_host). It is
the balancer that must stop sending traffic there before you touch the node. Without delegate_to, "take
out of the pool" would run on the node you are about to take down — you would ask the patient to operate
on themselves. Question c.

### Phase 4 — The full choreography: pre_tasks, tasks, post_tasks (27.4 — TODO 2)

A safe release has three movements, and with serial they repeat on every wave:

    pre_tasks:   drain      -> take the node out of rotation (delegate_to balancer)
    tasks:       update     -> apply the new release on the node
    post_tasks:  re-enable  -> put the node back in rotation (delegate_to balancer)

In the play you find the first two; the third is missing — the half everyone forgets. If you do not put
the node back in rotation, every wave leaves two backends out for good: at the end of the rollout the
farm is up but serves at half capacity. Complete **TODO 2**: add the post_tasks block that returns the
node to the pool, mirroring the drain —

    post_tasks:
      - name: Put the host back in the pool
        ansible.builtin.shell: 'echo "... ENABLE {{ inventory_hostname }} ..." >> {{ ledger }}'
        delegate_to: "{{ lb_host }}"
        changed_when: false

Now the choreography is closed: drain → update → re-enable, one wave at a time, and the ledger shows
every node leaving and returning.

### Phase 5 — The emergency brake: max_fail_percentage (27.5 — TODO 3)

A wave release, without a brake, still has a flaw: if the new release is broken, the first wave fails…
and Ansible moves to the second anyway, and the third — you propagate the fault across the whole farm,
one wave at a time. **max_fail_percentage** is the brake: if the share of failed hosts in a wave exceeds
the threshold, the play **stops** and does not touch the rest of the fleet. Complete **TODO 3** on the
play —

    max_fail_percentage: 25

With waves of two, a single failed node is 50% of the wave: it exceeds 25%, and the rollout halts there
— the nodes of the later waves are not even grazed. The value is a risk decision: 0 means "a single
failure and stop" (the strictest); a higher percentage tolerates a few faulty nodes before raising the
alarm. Question b.

### Phase 6 — When something goes wrong: rollback and recovery (27.6)

The brake stops the propagation, but it leaves a wound: **the wave in flight is left half-done**. When
the rollout halts, the nodes of that wave have already been drained (out of rotation) and maybe half
updated — but not re-enabled. The ledger shows it: after a halt, some node is DRAIN with no ENABLE. That
is why you need a **recovery**. The paths:

- **block/rescue/always** (ch. 22): put drain/update in a block, and the re-enable in always, so a node
  is returned to rotation *even if* the update fails.
- **A small serial is already safety**: fewer nodes in flight, less damage to repair when you stop. The
  blast radius is bounded by construction.
- **A real rollback**: a previous release ready, and a return playbook that re-applies the good version
  to the waves already touched.

The point: orchestration is not only "going forward well", it is "**stopping well**" — knowing what
state a halt leaves you in and having the way back.

### Phase 7 — Coordinating multiple tiers and groups (27.7)

A real application is not one group: web, database, cache, load balancers. The order between tiers
matters — usually the database before the web nodes, the balancers last. You express it with **multiple
plays in the same playbook**, one per group, in the right order; with **run_once** for actions that must
happen only once (a schema migration, not on every node); and with **delegate_to** to act on one tier
while updating another. Same vocabulary — serial, delegate_to, pre/post — orchestrated over several
sections instead of one.

### Phase 8 — Good habits (27.8)

- **Never all at once**: serial always, on any fleet that serves traffic. The default (all) is for labs,
  not production.
- **Drain and re-enable, always in pairs**: a node that leaves rotation must return; the re-enable goes
  where you cannot skip it (post_tasks or always).
- **The brake before the release**: max_fail_percentage set *beforehand*, not added after the first
  incident.
- **Stop well**: know what state a halt leaves you in and have the recovery ready (rescue/always,
  rollback).
- **Canary wave**: serial: [1, ...] — a single node first, so a fault shows on the smallest possible
  damage.

## Done when

- The play has serial: 2 (TODO 1): the release proceeds in waves, never the whole farm at once.
- The play has the post_tasks that re-enable the node (TODO 2): every drained node returns to rotation.
- The play has max_fail_percentage: 25 (TODO 3): a wave that fails stops the rollout.
- The pool ledger confirms it: every node leaves and returns, and **at every instant no more than one
  wave (2) is out of rotation**.

## How it is verified

solution/run.sh proves it, all locally and offline:

1. **The rolling choreography**: it runs the healthy release and reconstructs from the ledger that all 6
   nodes were drained, updated and re-enabled, and that **never more than 2** (serial) were out of the
   pool at the same time.
2. **The emergency brake**: it runs the release with one node failing its update and requires the
   rollout to **stop** after the first wave — the nodes of the rest of the farm are never touched.
3. **Why waves matter**: it widens the wave to the whole farm and shows the entire pool (6 nodes) going
   down at the same instant — the outage serial exists to prevent.

## Reflection questions

**a.** serial: 2 on a farm of 6 always keeps at least 4 nodes in rotation. How do you choose the number
on a real fleet? If the farm holds peak only with at least 80% of its nodes active, what is the maximum
serial you can use — and what changes if you express it as a percentage instead of a fixed number as
the farm grows?

**b.** The brake stops the propagation but leaves the wave in flight half-done (drained, not
re-enabled). Why is a **small** serial already a form of recovery safety in itself? And why does putting
the re-enable in an always (or rescue) instead of plain post_tasks change what happens when an update
fails halfway?

**c.** The drain and enable use delegate_to toward the load balancer. What would break, concretely, if
you removed delegate_to and the "remove from the pool" ran on the web node you are about to update? Why
is the action on the balancer the only one that makes sense?

## Cleanup

Nothing to tear down: no remote node, no container, no cloud account. The ledger is just a file:

    rm -f /tmp/cap27-pool.log
    deactivate

## Where it leads

You can release to a fleet without taking the service down: in waves, with the balancer in the loop,
with a brake and a recovery (ch. 27). But so far it is you — or your pipeline — who launches, and who
keeps inventories, credentials, who-can-do-what in your head. At the last Cloud Architect step, **chapter
28** takes all of this into a platform: **AWX and Automation Platform** — the job template, RBAC and
audit, workflows, Execution Environments — because at organisation scale automation itself becomes a
service with its own console, its own permissions and its own history.
