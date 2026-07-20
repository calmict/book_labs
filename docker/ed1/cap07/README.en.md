# Chapter 7 — Dying gracefully

**Level:** Intermediate

We close the engine's architecture by following a container from birth to death — and almost every trap
has the same root: that PID 1 you met "bare-handed" in chapter 1. In this lab you compare two containers
facing docker stop: one whose PID 1 ignores SIGTERM, and one with a real init in the right place. You
measure the difference — ten seconds versus an instant — and understand, stopwatch in hand, why so many
containers "always take ten seconds" to stop.

## Objectives

- Observe the docker stop sequence: SIGTERM, wait (the grace period), then SIGKILL (7.3).
- Recognise the PID 1 trap: a process that ignores SIGTERM waits the whole grace (7.3).
- Cure the trap with --init (tini) as PID 1, which forwards the signal (7.5).
- Read exit codes as a diagnosis: 137 (SIGKILL) versus 143 (clean SIGTERM) (7.3).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use Docker.
- The bare-hands PID 1 of chapter 1 and signals as a concept: here they present the bill.

## The scenario

In start/ you will find congrazia.sh: a script that should start two containers and time their stop, but
does not time it and records no exit code. You fill three gaps (TODO 1..3) using throwaway containers,
never restarting the daemon.

Prepare the environment:

    cd docker/ed1/cap07/start

### Phase 1 — The states and the stop sequence (7.1, 7.3)

A container is not on or off: it moves through states (created, running, exited). And when you stop it,
Docker does not "pull the plug": it sends SIGTERM, waits the grace period, and only if it is still alive
sends SIGKILL. How PID 1 reacts to that first signal makes all the difference.

### Phase 2 — Timing the stop (7.3 — TODO 1)

Open start/congrazia.sh and complete **TODO 1**, inside the measure function: stop the container with the
grace period and time the operation.

    local t0 t1
    t0=$(date +%s%N)
    docker stop -t "$GRACE" "$n" >/dev/null
    t1=$(date +%s%N)

### Phase 3 — The exit code as diagnosis (7.3 — TODO 3)

Complete **TODO 3**: print the elapsed milliseconds and the exit code, read with docker inspect. The exit
code tells the whole story: 137 (SIGKILL) if PID 1 ignored SIGTERM, 143 (SIGTERM) if it stopped cleanly.

    echo "$(( (t1 - t0) / 1000000 )) $(docker inspect -f '{{.State.ExitCode}}' "$n")"

### Phase 4 — The real init (7.5 — TODO 2)

Container A runs sleep as PID 1, which ignores SIGTERM. Complete **TODO 2**: make container B start with
--init, so tini becomes PID 1 and forwards SIGTERM to sleep, which then terminates at once.

    read -r b_ms b_code < <(measure b --init)

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- measure times the stop with the grace period (TODO 1) and records the exit code (TODO 3).
- Container B uses --init (TODO 2).
- run.sh prints OK 1..3 and ALL CHECKS PASSED: A waits the grace and exits 137, B stops at once and exits
  143, and A is clearly slower than B.

## How it is verified

solution/run.sh starts the two containers and times them, checking:

- **OK 1** — A ignores SIGTERM: it waits (almost) the whole grace and is killed with SIGKILL (exit 137).
- **OK 2** — B with --init stops instantly with a clean SIGTERM (exit 143).
- **OK 3** — the difference is PID 1: A is far slower than B; --init makes the difference.

## Reflection questions

**a.** Why does container A take the whole grace period to stop? Connect the answer to the special
treatment the kernel gives to signals for PID 1, and explain why this is the real cause of containers that
"always take ten seconds".

**b.** Container B stops instantly. What exactly changes with --init, and why is the cure not rewriting
the application but giving it an init in the right place? What does tini do, besides forwarding signals?

**c.** 137 and 143 are two diagnoses. What does each mean, and why will you meet them again in chapter 26?
Why is designing for SIGTERM — instead of suffering SIGKILL — a matter of data safety, not elegance?

## Cleanup

Nothing to tear down: both containers are removed by the script (docker rm, plus a safety trap) at the
end; the test works in a temporary directory it cleans up itself. The daemon is never restarted.

## Where it leads

With this chapter the engine has no more secrets: you know who runs a container (ch5), by which rules
(ch6) and how it lives and dies (ch7). The craft begins. **Part 3** opens with **chapter 8**: the anatomy
of an image — layers, digest, manifest — and from there you will build real Dockerfiles, optimised and
secure. For quick reference, see the volume's appendices.
