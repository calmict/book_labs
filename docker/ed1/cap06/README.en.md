# Chapter 6 — The OCI recipe

**Level:** Intermediate

In chapter 5 you saw a chain of distinct links. But why so much fragmentation? The answer is one word:
standards. In this lab you go down to the last link and build and run an OCI container by hand with runc —
with no Docker in the loop. You will generate the config.json, the exact recipe into which all of Part 1
condenses, and see that runc does nothing but execute it to the letter. Change the recipe and the
container changes: because the config.json is the container.

## Objectives

- Build an OCI bundle by hand and run it with runc, with no Docker in the loop (6.3).
- Read in config.json the Part 1 mechanisms listed as data (namespaces) (6.3).
- Prove runc is a faithful executor: changing the recipe changes the container (6.3).
- Understand why the OCI standard makes the parts interchangeable (6.4).

## Prerequisites

- A Linux with runc (part of Docker Engine) and python3. Docker is used only to build the minimal rootfs
  (by exporting busybox): from there on runc works on its own, without Docker.
- No root: we use a --rootless spec (a USER namespace and uid mapping), so no sudo.
- Part 1 as context: here you find it written down as a recipe.

## The scenario

In start/ you will find laricetta.sh: a script that should generate the OCI recipe and run it, but
generates nothing and runs nothing. You fill three gaps (TODO 1..3) so the recipe exists, runc executes
it, and a change to it is reflected in the container.

Prepare the environment:

    cd docker/ed1/cap06/start

### Phase 1 — The problem standards solve (6.1)

In the early days, every tool had its own format and its own way of running: an image built for one did
not run on the other. It was the risk of lock-in. The Open Container Initiative wrote common rules — not a
program, specifications — and from there the parts became interchangeable.

### Phase 2 — Generating the recipe (6.3 — TODO 1)

The script prepares a minimal rootfs from busybox. Open start/laricetta.sh and complete **TODO 1**:
generate the runtime-spec recipe, rootless, and record the namespaces it lists —

    runc spec --rootless
    python3 -c "import json;print('namespaces='+','.join(n['type'] for n in json.load(open('config.json'))['linux']['namespaces']))" > "$OUT/oci.txt"

A --rootless spec adds a USER namespace and a uid mapping, so runc runs without sudo.

### Phase 3 — Changing the recipe (6.3 — TODO 2)

Inside the run_recipe function, complete **TODO 2**: edit the recipe — set the command (echo of the
argument) and turn the terminal off, so the output is captured on stdout.

    python3 - "$1" <<'PY'
    import json, sys
    c = json.load(open('config.json'))
    c['process']['args'] = ['/bin/echo', sys.argv[1]]
    c['process']['terminal'] = False
    json.dump(c, open('config.json', 'w'))
    PY

### Phase 4 — Running with runc (6.3 — TODO 3)

Complete **TODO 3**: run the bundle with runc, which reads config.json and executes it.

    runc --root "$BUNDLE/state" run "oci-$1"

The script runs the recipe twice with different words: if runc is faithful, the output follows the recipe.

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- laricetta.sh generates the recipe and records the namespaces (TODO 1).
- run_recipe edits the config.json (command + terminal) (TODO 2) and runs it with runc (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED: the recipe lists the Part 1 namespaces, runc executes it,
  and changing the recipe changes the output.

## How it is verified

solution/run.sh builds and runs the OCI bundle and checks, point by point:

- **OK 1** — the config.json recipe lists the Part 1 namespaces as data (pid, mount, user, ...).
- **OK 2** — runc executes the recipe: the container prints the given word.
- **OK 3** — changing the recipe makes the container follow: the config.json is the container.

## Reflection questions

**a.** A container on disk is a rootfs directory plus a config.json file. Looking at the config.json,
which Part 1 mechanisms do you find listed as data? What does runc do, then, exactly, and why does this
mean there is nothing new "under the hood"?

**b.** You changed the args in config.json and the container printed the new word: the config.json is the
container. Why is this the very meaning of the runtime-spec standard? And why does it let you replace runc
with crun, or run the same bundle under Docker, Podman or Kubernetes?

**c.** The interchangeability of the parts is your insurance against lock-in. In what way? And why is it
also the bridge to the Kubernetes book — what does Kubernetes orchestrate, and through which link of the
chain from chapter 5?

## Cleanup

Nothing to tear down: each runc run ends with the container process and its state lives in a temporary
directory the test cleans up; the rootfs is built and deleted in the same ephemeral directory. No
persistent Docker container, no resource left on the host.

## Where it leads

You understood why the chain of chapter 5 is made of separate parts: because every joint is a public
standard. **Chapter 7** closes Part 2 by following a container through its whole life — the states, the
POSIX signals, the responsibilities of PID 1 — and pays back the debt of the bare-hands PID 1 of chapter
1.
