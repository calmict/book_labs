# Chapter 1 — Answers (model solution)

## The arc, at a glance

    # Phase 1 (crack 1): the naive script
    bash start/provision.sh        # first run: ok
    bash start/provision.sh        # second run: useradd: user 'app' already exists

    # Phase 3 (crack 3): blind guard, drift survives
    docker exec cap01-server2 sh -c 'echo "version=9.9" > /etc/app.conf'
    bash start/provision.sh        # runs clean...
    docker exec cap01-server2 cat /etc/app.conf   # ...but still version=9.9

    # Phase 4: content guard, convergence
    docker exec cap01-server2 sh -c 'echo "version=9.9" > /etc/app.conf'
    bash start/provision.sh        # (with TODO 2)
    docker exec cap01-server2 cat /etc/app.conf   # version=1.0

solution/run.sh drives this whole arc against three throwaway containers, with
guaranteed teardown.

## The three questions

**a. Repeatable vs convergent.**

Repeatability is a property of the *script*: I can run it again without it
erroring out. Convergence is a property of the *outcome*: whatever state a server
starts in, after the run it is in the desired state. They are not the same, and
TODO 1 proves it — the blind existence-guard made the script perfectly repeatable
(no more useradd crash, no more failures on re-run) while leaving the drifted
server at version=9.9. It ran clean and changed nothing, which is worse than
crashing: a crash is loud, silent non-convergence is not. In production the one
that matters is convergence, because reality drifts constantly — a hand fix, a
crashed process, a half-finished deploy — and the only useful guarantee is "run
this and the server will be correct afterwards", not "run this and it will not
error". A script you can re-run safely but that does not correct drift gives you a
false sense of safety: green output, wrong servers.

**b. Steps vs state.**

No — reading provision.sh tells you the *commands* that were issued (create a
user, write a file), not the *state* those commands are supposed to produce. To
answer "what should server2 look like?" you have to execute the script in your
head and track its effects, and even then you only learn what this script touches,
not the full intended state of the machine. If instead you had a *description* of
the state — user app present, /etc/app.conf equals version=1.0 — three things
change: it is readable as documentation (the desired state is the file), it is
diffable (you can compare desired against actual), and the tool, not you, works
out the steps to close the gap. That inversion — you say *what*, the tool computes
*how* — is the whole point of a declarative configuration manager, and it is where
convergence comes from for free: to converge you must first be able to state the
target.

**c. Three thousand servers; push vs pull.**

The serial for loop lacks, at least: (1) parallelism — three thousand servers one
after another is hours, not seconds; (2) per-host error handling — one unreachable
host with set -e stops the whole run, and even without set -e you get no report of
which hosts succeeded, which failed, and which were skipped; (3) any notion of the
result — it reports what it *did*, never what the fleet now *is*, so you cannot
tell a converged fleet from a broken one without inspecting all three thousand by
hand. (Others: no batching/rolling to limit blast radius, no retry on transient
failures, no inventory of what "all servers" even means.) On push vs pull: this
script is push — the centre reaches out and imposes state, so drift is only fixed
when someone remembers to run it. The pull model flips the initiative: each server
runs an agent that periodically fetches its desired state and re-applies it, so
drift is corrected on a schedule without anyone launching anything — at the cost of
an agent on every node and a source of truth the nodes can reach. Ansible chooses
push (agentless, nothing to install on the managed nodes); the trade-off is that
convergence happens when you run it, which is why later chapters lean on CI/CD and
scheduling to run it often enough that "when you run it" becomes "continuously".
