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
- Change the UTS namespace in the recipe and observe its effect on the hostname (6.3).
- Run the same bundle with two different runtimes and prove their interchangeability (6.4).

## Prerequisites

- A Linux with runc (part of Docker Engine), python3, and a second OCI runtime. The default is crun; you
  can select another one with CAP06_RUNTIME2. Docker is used only to build the minimal rootfs
  (by exporting busybox): from there on runc works on its own, without Docker.
- No root: we use a --rootless spec (a USER namespace and uid mapping), so no sudo.
- Part 1 as context: here you find it written down as a recipe.

## The scenario

In start/ you will find recipe.sh: a script that should generate the OCI recipe and run it, but
generates nothing and runs nothing. You fill five gaps (TODO 1..5) so the recipe exists, runc executes
it, a change to it is reflected in the container, and the same bundle works with two runtimes.

Prepare the environment:

    cd docker/ed1/cap06/start

### Phase 1 — The problem standards solve (6.1)

In the early days, every tool had its own format and its own way of running: an image built for one did
not run on the other. It was the risk of lock-in. The Open Container Initiative wrote common rules — not a
program, specifications — and from there the parts became interchangeable.

### Phase 2 — Generating the recipe (6.3 — TODO 1)

The script prepares a minimal rootfs from busybox. Open start/recipe.sh and complete **TODO 1**:
generate the runtime-spec recipe, rootless, and record the namespaces it lists —

    runc spec --rootless
    python3 -c "import json;print('namespaces='+','.join(n['type'] for n in json.load(open('config.json'))['linux']['namespaces']))" > "$OUT/oci.txt"

A --rootless spec adds a USER namespace and a uid mapping, so runc runs without sudo.


Mind how you paste it in: the body of a heredoc and the PY line that closes it must
start at column 0, even inside an indented function, or bash never sees its end.
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

### Phase 5 — Changing a namespace (6.3 — TODO 4)

Complete **TODO 4**: set the recipe command to hostname, give it a private hostname, and run it with the
UTS namespace present. Then remove the uts entry from linux.namespaces, remove the hostname field, and
run it again. The first container reads the recipe hostname; the second shares the host UTS namespace and
reads the host hostname.

Both elements must be removed together: if hostname remains in the recipe without a private UTS
namespace, runc rejects it because it cannot set a hostname in the host namespace. This constraint shows
that config.json is a coherent contract, not a collection of independent notes.

### Phase 6 — The same bundle, two runtimes (6.4 — TODO 5)

Complete **TODO 5**: prepare a single recipe that prints same-oci-recipe and run the same bundle first
with runc and then with the runtime selected by CAP06_RUNTIME2, crun by default. Use distinct --root
directories for the two runtimes' state. Neither the recipe nor the rootfs changes: only the engine does.

Once the five TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- recipe.sh generates the recipe and records the namespaces (TODO 1).
- run_recipe edits the config.json (command + terminal) (TODO 2) and runs it with runc (TODO 3).
- recipe.sh changes the UTS namespace and hostname field as parts of the same contract (TODO 4).
- recipe.sh runs the same bundle with runc and a second OCI runtime (TODO 5).
- run.sh prints OK 1..5 and ALL CHECKS PASSED: the recipe lists the Part 1 namespaces, its changes alter
  the container, and two runtimes execute the same bundle with identical output.

## How it is verified

solution/run.sh builds and runs the OCI bundle and checks, point by point:

- **OK 1** — the config.json recipe lists the Part 1 namespaces as data (pid, mount, user, ...).
- **OK 2** — runc executes the recipe: the container prints the given word.
- **OK 3** — changing the recipe makes the container follow: the config.json is the container.
- **OK 4** — a private UTS uses the recipe hostname; without it, the host hostname is observed.
- **OK 5** — runc and the second runtime execute the same OCI bundle with identical output.

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

**d.** Why must the hostname field be removed together with the private UTS namespace? What does this
constraint reveal about the nature of config.json?

## Cleanup

Nothing to tear down: each run by either runtime ends with the container process and its state lives in
distinct directories inside a temporary directory the test cleans up; the rootfs is built and deleted in
the same ephemeral directory. The temporary Docker container used to export busybox is removed even on
error. No persistent container, no resource left on the host.

## Where it leads

You understood why the chain of chapter 5 is made of separate parts: because every joint is a public
standard. **Chapter 7** closes Part 2 by following a container through its whole life — the states, the
POSIX signals, the responsibilities of PID 1 — and pays back the debt of the bare-hands PID 1 of chapter
1.
