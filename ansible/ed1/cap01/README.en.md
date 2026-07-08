# Chapter 1 — The three cracks

**Level:** Foundational

The manual opens with a promise: to become the conductor of your infrastructure
orchestra. But before you raise the baton you have to understand *why* the
hand-written score — the Bash script — crumbles when the players are not three
but three thousand. In this first lab we will **not use Ansible yet**: we install
it in chapter 6. Here you feel with your own hands the *problem* Ansible exists to
solve, so the rest of the manual has a reason to exist.

Three "servers" (three containers), one state you want to keep identical across
all of them, and a script that tries to enforce it. The script will work. Then
you re-run it, and the first crack opens.

## Objectives

- See the **three cracks** of imperative scripting in action: it is not
  repeatable, it describes *steps* not a *state*, and divergence is inevitable.
- Tell apart two ideas that look the same and are not: **repeatability** (I can
  re-run it without it blowing up) and **convergence** (it brings me back to the
  desired state, whatever the starting point).
- Understand why going from 3 to 3000 servers is not a quantitative but a
  qualitative jump, and what **push** and **pull** mean.

## Prerequisites

- A running **Docker** engine (the three containers act as servers). Check with:
  docker version
- Nothing else. In particular, **no Ansible**: that is deliberate — this is the
  world *before* automation.
- Note: we use docker exec to run commands "on the server". It stands in for the
  SSH you would use on a real machine (SSH is chapter 3); the crack you will see
  is identical.

## The scenario

Three servers in your fleet: cap01-server1, cap01-server2, cap01-server3. On each
you want the **same state**:

- the service user app exists;
- the file /etc/app.conf contains exactly version=1.0

Simple. We write it in Bash and run it on all of them. What could go wrong?

## Step by step

### Phase 0 — Bring the fleet up

    docker run -d --name cap01-server1 debian:12 sleep infinity
    docker run -d --name cap01-server2 debian:12 sleep infinity
    docker run -d --name cap01-server3 debian:12 sleep infinity

Three servers running. (On a real machine you would reach them over SSH; here
with docker exec.)

### Phase 1 — The naive script, and the first crack

Open start/provision.sh. In its starting form it does the most natural thing in
the world: for each server, create the user and write the config.

    for s in "${SERVERS[@]}"; do
      docker exec "$s" useradd app
      docker exec "$s" sh -c 'echo "version=1.0" > /etc/app.conf'
    done

Run it:

    bash start/provision.sh

It works: three servers configured. Now **run it again**:

    bash start/provision.sh

    useradd: user 'app' already exists

The script breaks: useradd exits with an error because the user already exists.
**Crack 1 — it is not repeatable.** An imperative script gives *orders*, it does
not ask *how things are*: it orders "create the user" even when the user exists.
In the real world this means you cannot safely re-run your script: the second run
is different from the first.

### Phase 2 — TODO 1: make it repeatable (by hand)

You have to teach the script to look before it acts. Complete **TODO 1** in
provision.sh: put a guard on each command, so the second run does not blow up.

- user: create it only if missing —

      docker exec "$s" sh -c 'id -u app >/dev/null 2>&1 || useradd app'

- config: in the starting form the TODO has you write a guard **on the file's
  existence** (the "obvious" choice: if the file is there, do not touch it) —

      docker exec "$s" sh -c 'test -f /etc/app.conf || echo "version=1.0" > /etc/app.conf'

Run it twice: no more errors. It looks solved. You have just rewritten by hand a
piece of what Ansible does for free — and you are about to discover you rewrote it
**wrong**.

### Phase 3 — The night sabotage, and the sneakiest crack

Someone logs into cap01-server2 and changes the config by hand (an emergency fix,
a slip, it does not matter):

    docker exec cap01-server2 sh -c 'echo "version=9.9" > /etc/app.conf'

The fleet has now **diverged**: two servers at 1.0, one at 9.9. This is exactly
what always happens in reality, and it has a name: **configuration drift**. Re-run
your guarded script — the one that "works":

    bash start/provision.sh
    docker exec cap01-server2 cat /etc/app.conf

    version=9.9

The drift **survived**. Your guard checked whether the file *exists*, not what it
*contains*: the file is there, so the script skipped it, leaving 9.9. **Crack 3 —
divergence is inevitable**, and a repeatable script is not enough to cure it. Here
is the chapter's central lesson: **repeatable does not mean convergent**. Re-running
without errors is one thing; bringing reality back to the desired state is another,
much harder thing.

### Phase 4 — TODO 2: from repeatability to convergence

Complete **TODO 2**: the guard on the file must not ask "do you exist?" but "are
you the way you should be?". The simplest form that always converges is to rewrite
the desired state on every run (idempotent by construction: writing version=1.0 a
thousand times leaves version=1.0):

    docker exec "$s" sh -c 'echo "version=1.0" > /etc/app.conf'

Sabotage server2 again, re-run, and watch:

    docker exec cap01-server2 cat /etc/app.conf

    version=1.0

Now it converges: whatever the starting state, the server goes back to 1.0. But
stop and look at what it cost you: for **one** line of config you had to reason
about existence, content, repeatability and convergence — and rewrite the guard
twice. Multiply that by every package, file, service and permission of a real
server. This work, done well and for you, is exactly what we call **configuration
management** — and it is Ansible's job.

### Phase 5 — The cracks you do not need your hands to see

Two observations close the picture, with no more code.

**Crack 2 — steps, not state.** Re-read provision.sh: it is a list of *commands*.
If a colleague asks you "what state should server2 be in?", you cannot answer by
reading the script — you can only *run it in your head*. A declarative tool flips
this around: you describe the *desired state* and it works out the steps. The
script says *how*; Ansible will let you say *what*.

**Three, thirty, three thousand.** Your for loop is **serial** and **push** (you,
from the centre, push commands out to the servers). With three servers it holds.
With three thousand: no parallelism, and if server1743 is unreachable the script
stops right there — without telling you which of the earlier ones were already in
order and which were not. Try it:

    docker stop cap01-server3
    bash start/provision.sh    # watch where it stops and what it does NOT tell you
    docker start cap01-server3

This is the qualitative jump of 1.1: at three thousand servers you need
parallelism, per-host error handling, and a way to *describe* the state instead of
*ordering* it. It is also the **push vs pull** choice: here the centre pushes; in
the pull model each server would go and fetch its own configuration at intervals.
Ansible is push — and the coming chapters give you everything the script lacks.

## Done when

- The starting script **fails on the second run** with the useradd error (crack 1
  seen).
- With TODO 1's guards the script **re-runs without errors**, but after the
  sabotage the drift on server2 **survives** with the blind guard (crack 3 seen).
- With TODO 2 (content guard) server2 **goes back to version=1.0** after the
  sabotage (convergence).
- You can explain in your own words why *repeatable* is not *convergent*, and why
  at 3000 servers the imperative script is not enough.

## Questions to reflect on

**a.** Your guarded script from TODO 1 re-ran "without errors", yet let the drift
slip through. What separates *repeatability* from *convergence*, and why is the
latter the one that really matters in production?

**b.** Looking at provision.sh, could you tell a colleague what the *desired state*
of a server is without running the script? What would change if, instead of a list
of commands, you had a *description* of the state?

**c.** At three thousand servers, list at least three things your serial for loop
lacks. Then: how would the *pull* model tackle the drift problem differently from
the *push* of this script?

## Cleanup

    docker rm -f cap01-server1 cap01-server2 cap01-server3

## Where it leads

You have touched the three cracks with your own hands. From chapter 6 you install
Ansible; from chapter 10 you write your first playbook — where idempotence and
convergence are not rewritten by hand on every line, but handed to you by the
module. This chapter is the "before": the pain that justifies all the rest.
