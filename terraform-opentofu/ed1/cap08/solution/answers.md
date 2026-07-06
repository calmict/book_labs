# Chapter 8 — Answers (model solution)

## The two worlds (Phase 0)

    # local:      27.x (your version)
    # tcp 23750:  27.5.1 (the dind's own engine — potentially different)

## Who sees what (Phase 3)

    docker_container.web_frankfurt
    docker_container.web_milan
    docker_image.web_frankfurt
    docker_image.web_milan

    # Milan side:     cap08-web-milan, cap08-frankfurt-dc
    # Frankfurt side: cap08-web-frankfurt

## The asymmetric demolition (Phase 5)

    # docker -H tcp://127.0.0.1:23750 ps -a : empty
    # cap08-frankfurt-dc: still alive (hand-made) — then removed by hand

## The three questions

**a. Translator and telephones.**

init installed exactly ONE binary: the kreuzwerker/docker provider — one
translator, whatever the number of worlds. The two provider blocks
configured two LINES on that same translator: the default one (no alias,
local socket) and the named one (alias frankfurt, tcp 23750). Frankfurt's
image needed the placement line too because an image lives INSIDE an
engine: the two worlds share no image cache, no network, no inventory —
so "the same nginx" is in fact two pulls, one per datacenter. A resource
with no provider meta-argument travels on the default line: it would have
landed in Milan, silently — which is exactly why explicit placement,
written in code, beats any implicit context.

**b. The ladder of trust.**

The AWS block carries no credential at all: identity arrives from outside
— environment variables or a named profile — read by the provider at
runtime, never stored in the code. assume_role climbs one rung: the outer
credentials are used only to obtain TEMPORARY credentials for a role, so
the session expires by itself (duration), the role carries only the
permissions this project needs (perimeter), and there is one clear thing
to disable and one clear trail to audit (revocation). The vSphere
password in the .tf is permanent damage because committing it puts it
into git history, and history propagates: every clone, every mirror,
every backup carries it forever — deleting the line tomorrow removes it
from the working tree, not from the past. A committed secret is a
compromised secret; the only real fix is rotating it.

**c. The asymmetric demolition, and the lab shortcut.**

The destroy removed the four resources it had created, each through its
own line: Milan's nginx and image over the default socket, Frankfurt's
over tcp 23750 — one command, two worlds, the graph walked backwards per
provider. It left the dind container standing, because tofu demolishes
only what it built (chapter 6): the datacenter was made by hand, so it is
outside the contract — the same boundary that protects every pre-existing
thing on a shared machine. The boundary is right because the alternative
(razing whatever it can see) would make the tool unusable anywhere
reality is shared. The lab shortcut — the Docker API in plaintext on
23750 — would be unacceptable beyond localhost: production would demand
an encrypted, authenticated line (tcp with mutual TLS, or ssh://), which
is the same golden rule again — the code names the endpoint, the trust
material lives outside.
