# Chapter 7 — Answers (model solution)

## The closed gate (Phase 0)

    Error: Unsupported OpenTofu Core version

## The register's birth (Phase 1)

    version     = "3.5.1"
    constraints = "3.5.1"
    "h1:8EQU5KSxezcjo/phRSe69rDOI0lk4pSaggj7FsskYp8=",

## The fence and the choice (Phase 2)

    - Reusing previous version of hashicorp/random from the dependency lock file

## The deliberate gesture (Phase 3)

    <   version     = "3.5.1"
    >   version     = "3.9.0"
    # (your latest 3.x may differ — the point is that it changed, and only
    # because you asked)

## The conflict (Phase 4)

    must use tofu init -upgrade to allow selection of new versions

## The July colleague (Phase 5)

    # the latest 3.x (3.9.0 at the time of writing) — not January's 3.5.1

## The three questions

**a. The gate: which team scenario, why at init, and why two separate
kinds of constraint?**

required_version protects the project from being driven by the wrong
engine: the classic scenario is the colleague (or the CI runner) with a
binary two years older — or newer — than what the code was written for,
who would otherwise run it and fail halfway, or succeed with subtly
different behaviour. It fires at init because that is the earliest
possible moment: before providers are chosen, before state is read,
before any plan exists — a wrong core must not get past the front door.
The two constraint kinds pin different programs: required_version pins
the core (the engine you installed: tofu or terraform itself), while each
entry in required_providers pins one translator (a plugin with its own
release history and its own breaking changes). Core 1.9 with random 3.5
and core 1.9 with random 4.0 are different toolchains: each piece needs
its own fence.

**b. The separation of powers: fence versus choice.**

In Phase 2 I changed only the constraint — the fence — from "3.5.1" to
"~> 3.5": init answered by REUSING 3.5.1 from the lock, because a wider
fence is not an order to move, only permission. In Phase 3 I changed the
choice, deliberately, with init -upgrade: the tool picked the newest
version inside the fence and rewrote the register — a diff a team can
review. In Phase 4 the two contradicted each other (fence said exactly
3.5.1, register said 3.9.0) and the tool stopped with an error naming the
way out, because both silent options betray someone: a silent downgrade
betrays whoever upgraded on purpose, a silent upgrade betrays whoever
pinned on purpose. ~> 3.5 promises: any 3.x from 3.5.0 on — patches and
minors, which semver reserves for compatible changes — and never 4.0,
because the major is where semver authorises breakage; the fence keeps
out exactly the versions allowed to break you.

**c. The July colleague, the hashes, and where the lock belongs.**

The colleague cloned code whose lock file was never committed: his init
had only the fence (~> 3.5) to go by, so it picked the newest allowed
version — months of provider releases away from the 3.5.1 the January
lock had chosen. Same code, different toolchain: drift, climbed up from
the servers to the tools. One action would have prevented it: committing
.terraform.lock.hcl, so every clone re-installs the recorded choice
byte-for-byte. The hashes add integrity on top of reproducibility: they
are the package's fingerprints, and an init whose download does not match
them refuses to proceed — protection against a tampered registry or a
corrupted mirror, not just against version skew. This exercise repo
gitignores the lock only because every reader must be able to run these
experiments (breaking, upgrading, deleting it) from a clean slate; your
next real project inverts the rule: the register goes into git, next to
the code whose choices it records.
