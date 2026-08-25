# Chapter 6 - The OCI recipe - answers

## The completed TODOs

TODO 1 (6.3) - generate the runtime-spec recipe, rootless, and record the
namespaces it lists. A rootless spec adds a USER namespace and a uid mapping, so
runc runs without sudo:

    runc spec --rootless
    python3 -c "import json;print('namespaces='+','.join(n['type'] for n in json.load(open('config.json'))['linux']['namespaces']))" > "$OUT/oci.txt"

TODO 2 (6.3) - edit the recipe: set the command and turn the terminal off so the
output is captured on stdout:

    python3 - "$1" <<'PY'
    import json, sys
    c = json.load(open('config.json'))
    c['process']['args'] = ['/bin/echo', sys.argv[1]]
    c['process']['terminal'] = False
    json.dump(c, open('config.json', 'w'))
    PY

TODO 3 (6.3) - run the bundle with runc. It reads config.json and executes it:

    runc --root "$BUNDLE/state" run "oci-$1"

TODO 4 (6.3) - run hostname with a private UTS namespace and a recipe hostname,
then remove both the uts namespace entry and the hostname field and run it again.
The two fields form a contract: runc correctly rejects a recipe that asks it to
set a hostname without giving the container a private UTS namespace.

TODO 5 (6.4) - set one recipe to print same-oci-recipe and execute the unchanged
bundle with runc and with CAP06_RUNTIME2 (crun by default). The runtimes use
distinct state roots, but consume the same config.json and rootfs.

## Reflection answers

a. A container on disk is just two things: a rootfs directory (the filesystem,
the overlay of chapter 4) and a config.json (the recipe). The recipe lists, as
plain data, everything you built by hand in Part 1: the namespaces to create
(chapter 2), the resources section with cgroup limits (chapter 3), the root.path
pointing at the rootfs (chapter 4), the capabilities (chapter 24). runc is simply
the faithful executor of that recipe - it creates what config.json says and runs
the process. Nothing new happens under the hood; Part 1 is automated and written
down as a standard document.

b. runc executes whatever the recipe says: change the args in config.json and the
container prints the new word; the config.json is the container. This is the
whole point of the runtime-spec standard - any conformant runtime, given the same
bundle, produces the same result. It is why you could replace runc with crun and
notice nothing, and why the same OCI bundle runs under Docker, Podman or
Kubernetes: the recipe is standard, the executor is interchangeable.

c. This interchangeability is your insurance against lock-in. Because your images
and bundles are OCI, they keep running on containerd, Podman or Kubernetes even
if Docker changed direction - without rewriting anything. It is also the bridge
to the next volume of the series: Kubernetes orchestrates exactly these OCI
containers, through containerd, without Docker in the middle. What you learn here
about config.json does not expire when you change tools; it is the common
foundation.

d. hostname is a property of a UTS namespace. If the recipe omits a private UTS
namespace, the process shares the host's namespace and the runtime must not change
its hostname. Keeping the hostname field would therefore make the instructions
contradictory, and runc rejects them. Removing both demonstrates that config.json
is a validated contract whose fields describe one coherent container, rather than
unrelated hints a runtime may apply selectively.
