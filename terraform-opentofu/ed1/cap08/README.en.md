# Chapter 8 — One translator, two sites

**Level:** Foundational
**Estimated time:** 45–55 minutes
**Manual topics:** the Core and Provider architecture (8.1), the central problem: authentication (8.2), authentication on AWS: roles (8.3), Azure and Google Cloud (8.4), the on-premise case: vSphere (8.5), multiple providers and aliases (8.6), the golden rule of security (8.7)

## The idea

In chapter 6 you weighed the translator: a binary of tens of megabytes
inside .terraform. But the binary alone is not enough: you must tell it
*which world* to talk to — and that is the provider block's trade. Here
you discover it in the most concrete way possible: you build a **second
datacenter on your machine** (a Docker inside Docker: a real, separate
engine, reachable over the network) and configure *two instances of the
same translator* — the default line towards the Milan site and an aliased
line towards the Frankfurt one. Then you place the same nginx in both,
deciding the destination resource by resource with a single line:
provider =.

The second half of the chapter is to be read, not executed: a gallery of
real provider blocks — AWS with roles, vSphere with the password in the
wrong place and then in the right one — leading to the golden rule: the
code says *where* and *how* to connect, never *who you are*: secrets live
outside the code, always.

## Goals

By the end you will be able to:

- tell the provider-binary (the translator init installs) from the
  provider block (the configured line towards a real system);
- declare multiple instances of the same provider with alias, and place
  each resource with the provider = meta-argument;
- read an AWS provider block with assume_role and explain why roles beat
  static keys;
- spot the capital sin (credentials in code) at a glance, and its fix;
- say what tofu destroy removes in a multi-provider scenario — and what
  it does not touch.

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md.
- Docker running, able to launch a privileged container (datacenter
  number two needs it).
- Free ports: 8091, 8092 and 23750.

## Your task

### Phase 0 — The second datacenter

The Milan site you already have: it is your local Docker. Frankfurt must
be built — and it is a privileged container with a whole Docker engine
inside, exposed over the network on port 23750:

    docker run -d --name cap08-frankfurt-dc --privileged \
      -e DOCKER_TLS_CERTDIR="" \
      -p 127.0.0.1:23750:2375 -p 127.0.0.1:8092:8092 \
      docker:27-dind

Give it a few seconds to start, then verify the two worlds answer and are
*really* separate:

    docker info --format '{{.ServerVersion}}'
    docker -H tcp://127.0.0.1:23750 info --format '{{.ServerVersion}}'
    docker -H tcp://127.0.0.1:23750 ps

Two engines, two inventories, two potentially different versions. (Honest
note: 23750 is plaintext, no TLS, bound to 127.0.0.1 — a lab shortcut. In
production that line would be encrypted: tcp+TLS or ssh://.)

### Phase 1 — The two lines (TODO 1)

Open start/main.tf: the terraform block declares the docker translator —
one, and init will install one. The *lines* towards the two worlds are
another thing, and the second one you write yourself:

    provider "docker" {}

    provider "docker" {
      alias = "frankfurt"
      host  = "tcp://127.0.0.1:23750"
    }

Same type, two configurations: the first (no alias) is the default line;
the second has a name, and whoever wants it must ask for it by name. That
is what the provider block is: not the translator, but its telephone —
with the number to dial written on it.

### Phase 2 — The same nginx, in two worlds (TODO 2)

Milan's resources are already written: look at them, they are chapter 6.
TODO 2 asks you for Frankfurt's twins: same image, same container (port
8092), plus ONE line that changes everything:

    provider = docker.frankfurt

It is the placement meta-argument: without it, the resource goes on the
default line; with it, it goes where you say. Note that it is needed on
*both* Frankfurt resources — the image too must be downloaded *in that*
datacenter: the two engines share nothing, not even the image cache.

    tofu init
    tofu apply

### Phase 3 — Who sees what

    tofu state list
    docker ps
    docker -H tcp://127.0.0.1:23750 ps
    curl http://127.0.0.1:8091
    curl http://127.0.0.1:8092

Four resources in a single state — but Milan sees only its container, and
Frankfurt only its own. Placement is not an implicit context (an
environment variable, an active "docker context"): it is *written in the
code*, resource by resource, and survives whoever runs the apply from
whatever terminal. Both curls answer: welcome to desktop multi-region.

### Phase 4 — The authentication gallery (read, do not execute)

With Docker the connection was a socket or a URL. With clouds the
question becomes: *who are you to make these calls?* In start/examples/
you will find two .tf.example files (the extension makes them invisible
to tofu: they are for reading):

- **aws.tf.example** — the ladder of trust: in the provider block there
  is NO credential (they come from outside: environment variables or a
  profile), and the step above is assume_role — personal keys obtaining
  *temporary* credentials of a role, with bounded permissions and an
  expiry. Azure and Google follow the same principle with their own
  identities (Managed Identity / service accounts, or the corporate CLI).
- **vsphere.tf.example** — the on-premise case, in two versions: the one
  with the capital sin (username and password *written in the .tf*,
  destined to live in git forever) and the correct one (the block states
  only the server; credentials arrive from environment variables).

The golden rule, valid from Docker to AWS: the code declares where and
how to connect; identity and secrets live outside — environment, ignored
files, vaults. A committed secret is compromised forever: git history
does not forget.

### Phase 5 — The asymmetric demolition

    tofu destroy
    docker ps
    docker -H tcp://127.0.0.1:23750 ps -a

The four objects are gone — from *both* worlds, each through its own
line. But the Frankfurt datacenter is still there: you created it by
hand, and tofu (chapter 6) demolishes only what it built itself. You
close the symmetry:

    docker rm -f cap08-frankfurt-dc

### Cleanup

Done in Phase 5 (destroy + dind removal). The nginx images remain
(keep_locally, Milan side only); docker rmi if you want them gone.

## Definition of done

- The two engines answered separately (docker info locally and via
  tcp://127.0.0.1:23750).
- tofu state list showed 4 resources; docker ps saw one per engine (plus
  the dind, Milan side).
- Both curls (8091 and 8092) answered with the nginx page.
- After the destroy: Frankfurt's engine empty, but the
  cap08-frankfurt-dc container still alive — then removed by hand.
- You read the two .tf.example files and can point at the capital sin
  and its fix.
- You answered the three questions in answers.md.

## The three questions

**a.** Translator and telephones: what did init install (how many
binaries?) and what did the two provider blocks configure? Why did
Frankfurt's image need provider = docker.frankfurt too — what does that
tell you about what the two worlds (do not) share? And what would have
happened to a resource with no provider meta-argument?

**b.** The ladder of trust: in the gallery's AWS block there is no
credential — where do they come from? What does assume_role add over
static keys (think duration, perimeter and revocation), and why is "the
password in the .tf" of vSphere a *permanent* damage and not just a style
mistake?

**c.** The asymmetric demolition: list what the destroy removed (and
through which lines) and what it left. Why is the boundary "I destroy
only what I created" the right choice here too? And the lab shortcut —
plaintext 23750 — what would it require in production?
