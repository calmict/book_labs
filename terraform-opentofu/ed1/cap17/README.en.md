# Chapter 17 — The prefab

**Level:** Intermediate
**Estimated time:** 50–60 minutes
**Manual topics:** what a module is (17.1), anatomy of a local module (17.2), remote modules and the Registry (17.3), modules and providers: the aliased provider (17.4)

## The idea

For sixteen chapters you have written the same pattern: variables at the top,
resources in the middle, outputs at the bottom. And every time you rewrite it
from scratch, folder after folder. A real architect does not redraw the same
building for every lot: they design it once as a **prefab**, then drop it into
the city as many times as needed, each with its own finishing.

The prefab, here, is the **module**: a folder with .tf files, but seen as a *box
with doors*. The input doors are its variables (name, environment, port); the
machinery inside is the resources (image and container); the output doors are
its outputs (the URL where it answers). Whoever uses the box does not look
inside: they pass inputs to the input doors, and read results from the output
doors. They are exactly chapter 14's variables and outputs — but promoted to the
*interface* of a reusable component.

You will build the prefab once, then call it from the root configuration with
for_each (chapter 15's legacy) to raise two isolated instances — a blog in dev,
a shop in prod — from a single design of the box. You will notice two things
that become chapters of their own: that the module does *not* declare its own
provider (it inherits it from the root, which opens the topic of aliased
providers), and that tucking resources into a box changes their *address* — and
that is exactly where Part 5 picks up.

## Goals

By the end you will be able to:

- say what a module is and recognise its three parts (variables = input doors,
  resources = machinery, outputs = output doors);
- write a local module and call it from the root with a module block (source +
  inputs);
- instantiate the same module several times with for_each, each isolated, and
  aggregate their outputs;
- explain why a module inherits the provider from the root, and when instead it
  must be passed explicitly (the aliased provider, 17.4);
- recognise a remote module from the Registry (source + version) and why the
  version must be pinned.

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md.
- Docker running. Free ports: 8101 and 8102.
- Chapters 14 (variables and outputs) and 15 (for_each): here they become a
  box's interface and multiplier.

## Your task

### Phase 0 — Anatomy of the box (17.2)

Open start/modules/webapp/main.tf: it is the prefab. Read it as a box with three
parts:

- **input doors** — the variables name, environment (with its validation,
  chapter 14's echo), external_port;
- **machinery** — a docker_image and a docker_container, with the name derived
  in a local (cap17-name-environment);
- **output doors** — the outputs url and container_name.

Notice something missing: inside the module there is *no* provider "docker" {}
block. The module only declares, in the terraform block, that it *needs* the
docker provider (required_providers) — but it inherits its *configuration* from
whoever calls it. A prefab does not carry its own power station: it plugs into
the neighbourhood's. Keep it in mind for Phase 5.

### Phase 1 — The output door (TODO 1)

The box is almost finished: one output door is missing. TODO 1, in
modules/webapp/main.tf, asks you to complete the url output — what the box
*promises* to whoever uses it. Replace the placeholder:

    output "url" {
      value = "http://localhost:${var.external_port} (${var.environment})"
    }

It is the only thing the outside world will read of the container: the
interface, not the implementation.

### Phase 2 — Dropping the prefab (TODO 2)

Now the root configuration, in start/main.tf. The apps variable is already
there: a map of two applications (blog in dev on 8101, shop in prod on 8102).
TODO 2 asks you for the module block that calls the box, once per application:

    module "webapp" {
      source   = "./modules/webapp"
      for_each = var.apps

      name          = each.key
      environment   = each.value.environment
      external_port = each.value.external_port
    }

source says *where* the box is (a local path); for_each instantiates it once per
map entry; the three lines pass the inputs to the input doors. A module must be
*installed*, like a provider:

    cd start
    tofu init

Read "Initializing modules... webapp in modules/webapp": init now installs
modules too, not just providers.

### Phase 3 — The aggregate output doors (TODO 3)

TODO 3, still in the root, gathers the two instances' URLs into a single output.
Replace the placeholder:

    output "urls" {
      value = { for k, m in module.webapp : k => m.url }
    }

module.webapp is the collection of instances; m.url reads each one's output
door. Apply and look:

    tofu apply
    tofu state list
    tofu output urls

In the addresses you see the module's namespace:
module.webapp["blog"].docker_container.this, module.webapp["shop"]... — the
resources now live *inside* the box. And the aggregate output gives blog → 8101
(dev), shop → 8102 (prod).

### Phase 4 — One box, many instances

See reuse at work. The two applications are isolated: remove the shop from the
map and ask for the plan (do not apply):

    tofu plan -var 'apps={ blog = { environment = "dev", external_port = 8101 } }'

Only module.webapp["shop"].* is destroyed: blog does not move. It is chapter
15's for_each, but over a whole module — each instance has its own identity, and
the prefab is a single one. Check both containers answer too:

    curl -s localhost:8101 | grep -o '<title>.*</title>'
    curl -s localhost:8102 | grep -o '<title>.*</title>'

### Phase 5 — Registry, aliased providers, and the bridge (reading)

Two things the manual shows, which you find here as examples to read in
start/examples/:

- **registry-module.tf.example** (17.3): the same module block, but with a
  source pointing at the *Registry* (terraform-aws-modules/vpc/aws) and a pinned
  version. Remote modules are other people's prefabs: the version is your lock
  (chapter 7), because you do not want the box changing under your feet.
- **aliased-provider.tf.example** (17.4): how to *pass* a provider to a module.
  By default a module inherits the root's default provider (Phase 0); but if you
  want its resources born in chapter 8's second datacenter, you pass it
  explicitly with providers = { docker = docker.frankfurt }.

And the bridge: by tucking the resources into the box, their *address* changed —
from docker_container.this to module.webapp["blog"].docker_container.this. But
chapter 15 taught us the address *is* the identity: moving a resource into a
module would normally destroy and rebuild it. Part 5 opens exactly here —
chapter 18 teaches how to change an address *without* destroying (the moved
block).

### Cleanup

    tofu destroy

## Definition of done

- The module had no provider "docker" {} block: it inherited the provider from
  the root.
- After TODO 2, tofu init printed "webapp in modules/webapp".
- The state addresses had the module.webapp["blog"]/["shop"] prefix.
- tofu output urls gave blog → 8101 (dev) and shop → 8102 (prod).
- Removing shop from the map, the plan destroyed only the shop instance.
- You answered the three questions in answers.md.

## The three questions

**a.** The box and its doors: map the module's three parts (variables,
resources, outputs) onto the three roles (input doors, machinery, output doors),
and explain why the outputs are the *interface* and not a detail — what can the
module's author change without breaking its users, and what cannot they?

**b.** Provider inheritance: why does the module not declare a provider
"docker" {} block and inherit it from the root? What changes if you want its
resources born in an *aliased* provider (chapter 8), and with which line do you
say so? Why is it a choice of whoever *calls* the module, not of whoever writes
it?

**c.** The Registry and the bridge: in a remote module (source pointing at the
Registry), why is pinning the version as important as chapter 7's lock file? And
finally: wrapping the resources in the module changed their address — why is
that a problem (what does chapter 15 say about the address as identity), and
which chapter of Part 5 solves it?
