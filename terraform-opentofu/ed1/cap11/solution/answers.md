# Chapter 11 — Answers (model solution)

## Inside the notebook (Phase 1)

    "serial": 1
    "lineage": "0f253aa7-e5d6-a226-65c7-ba23915c26d3"
    "f65e3c74b936...  (the container's real id, bound to docker_container.web)

    "dependencies": ["docker_image.web"]

## The secret (Phase 2)

    db_password = <sensitive>          (the output)
    "result":"=j&zgw]t..."             (the state — plain text)

## The three sources (Phase 3)

    Note: Objects have changed outside of OpenTofu
    # docker_container.web has been deleted

    docker_image.web
    random_password.db
    # (memory synced; reality untouched; the code then rebuilt via plan+apply)

## The colleague (Phase 4)

    Plan: 3 to add, 0 to change, 0 to destroy.
    Error: ... The container name "/cap11-web" is already in use ...
    docker_image.web
    random_password.db

## The three questions

**a. What the notebook knows.**

The code declares an intent ("one container, called web in my model");
reality contains objects with ids but no memory of which model created
them. The notebook holds the one fact neither side has: the BINDING —
docker_container.web IS container f65e3c74…, this password IS that
generated value. Without it, every plan would face reality as a stranger
(exactly the colleague's fate in Phase 4). Dependencies are recorded
because the code cannot always be trusted to still be there: if I delete
the container block from the code and run apply, the tool must destroy
the orphan — and to destroy several orphans in the right (reverse) order
it needs the edges as they were at creation time, not as the current code
(which no longer mentions them) would say.

**b. The secret and the memory-only sync.**

The state must hold the real value because it is the tool's only memory
of what exists: to detect drift on the password, to feed it into
references, to know whether tomorrow's plan changes it, the actual string
has to be stored — sensitive is a display rule (outputs, plan rendering),
not a storage rule. Consequences: the state never enters git (this repo
gitignores it), its home must have restricted access and encryption at
rest — which is one of the real jobs of chapter 12's backends — and
OpenTofu's native state encryption (chapter 20) exists precisely for this
file. -refresh-only is the memory-only sync: it reconciles
notebook↔reality while ignoring the code, proposing no construction. You
want it when the world legitimately changed behind the model — an object
deleted or altered out-of-band — and you need the notebook truthful
BEFORE deciding what to do about the code: taking note is one decision,
rebuilding is another, and the flag keeps them separate.

**c. The colleague and the single notebook.**

His code said "a password, an image, a container named cap11-web" — the
same as mine. His memory said "nothing exists". Reality contained MY
container under that very name. So his plan honestly proposed a full
rebuild, and his apply crashed exactly where the two truths met: the
contested name — leaving his notebook half-written (password and image
created, container failed). Chat discipline cannot fix this because the
failure is structural, not behavioural: whatever we agree verbally, HIS
tool still reasons from HIS memory — coordination would have to be
perfect, forever, for every colleague and every CI job. The single
notebook of chapter 12 must guarantee at minimum: one authoritative copy
everyone reads and writes (so every plan sees the same bindings), safe
storage for its secrets (access control, encryption), and a LOCK —
because two simultaneous applies on the same notebook would interleave
reads and writes and corrupt the memory itself; the lock serialises them:
one writer at a time, everyone else waits.
