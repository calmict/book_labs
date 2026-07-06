# Chapter 7 — The version register

**Level:** Foundational
**Estimated time:** 40–50 minutes
**Manual topics:** what the terraform block is for (7.1), required_version: pinning the binary (7.2), semantic versioning and its operators (7.3), required_providers: declaring the translators (7.4), the lock file .terraform.lock.hcl (7.5), pulling the threads (7.6)

## The idea

A serious construction site has a specification book: which standards
apply, which suppliers are admitted, and a register of *exactly* which
materials were chosen. In a project, the specification book is the
terraform block — and in this exercise you put it to the test by breaking
and repairing it: an impossible required_version slams the gate in your
face (and that is a good thing: you will discover what it protects from),
an exact pin shows you the birth of the lock file, and then the game gets
subtle — you widen the constraint with the ~> operator and discover that
*nothing changes*, until you ask for it yourself with init -upgrade.

It is the separation of powers that holds teamwork together: the
*constraint* in the code is the fence (what would be acceptable), the
*lock* is the choice (what we all actually use, today). The exercise
closes with the July colleague: he deletes the register, re-runs init, and
gets a different translator from yours — same code, months later,
different provider. It is the drift of chapters 1 and 2, climbed up from
the world of servers to the world of tools.

## Goals

By the end you will be able to:

- explain what the terraform block is for and what required_version
  protects from;
- read and choose semver operators, and state what ~> 3.5 promises (and
  forbids);
- tell the separation of powers: constraint = fence, lock = choice;
- use init -upgrade as a deliberate gesture, and read the conflict error
  between constraint and lock;
- say why in a real project the lock file must be committed (and why in
  this exercise repo, exceptionally, it is gitignored).

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md. The random provider
  (small: repeated inits cost a few seconds).
- Chapter 6: you already know what init does and where providers live.

## Your task

### Phase 0 — The closed gate

Open start/main.tf: this time it is complete, but the specification book
is broken by design — required_version demands a binary that no longer
exists. Try:

    cd start
    tofu init

Error: Unsupported OpenTofu Core version. The gate worked. Pause and think
about what it just protected you from: not from you — from the colleague
with the two-year-old binary who, without this check, would apply your
code with an engine that does not understand it, failing halfway or
(worse) succeeding differently. TODO 1 asks you to open the gate to
anyone with a modern binary:

    required_version = ">= 1.6.0"

(It holds for both binaries: OpenTofu was born at 1.6.)

### Phase 1 — The exact pin and the register's birth

The random provider is pinned to the exact version 3.5.1. Now that the
gate is open:

    tofu init
    cat .terraform.lock.hcl
    tofu apply

In the newborn lock file read three things: the chosen version (3.5.1),
the constraint that allowed it, and a list of hashes — the package's
fingerprints: at the next inits, a download that does not match is
rejected (supply-chain integrity, not just reproducibility). The apply
gives you the site's mascot: a random_pet, an old acquaintance from
chapter 1.

### Phase 2 — The fence widens, the choice stays

TODO 2 asks you to replace the exact pin with the pessimistic operator:

    version = "~> 3.5"

It means: >= 3.5.0 and < 4.0.0 — I accept patches and minors (fixes,
compatible additions), I refuse the major (where semver authorises
breakage). Now re-run:

    tofu init

Read carefully: Reusing previous version of hashicorp/random from the
dependency lock file. You widened the fence up to 3.9.x, and *nothing*
changed: 3.5.1 stays. It is the most important moment of the chapter: the
constraint says what would be acceptable, the lock says what is used —
and no ordinary init changes the choice behind your back.

### Phase 3 — The deliberate gesture

Upgrading is possible: but it is a gesture, not an accident.

    cp .terraform.lock.hcl lock.before
    tofu init -upgrade
    diff lock.before .terraform.lock.hcl

Now you are on the latest 3.x, and the lock's diff shows the new version
and the new hashes. In a team, this diff would go into the commit:
"upgraded the random provider", reviewable like any other change.

### Phase 4 — The conflict (and the error that guides you)

Go back to the earlier exact pin, without touching the lock:

    version = "3.5.1"

and re-run init. The error is one of the well-made ones: locked provider
... does not match configured version constraint ... must use tofu init
-upgrade. Constraint and register contradict each other, and the tool
*refuses to choose by itself*: no silent downgrade, no silent upgrade —
it tells you what the conflict is and what the gesture is to resolve it.
Put ~> 3.5 back and move on.

### Phase 5 — The July colleague

In January your lock said 3.5.1. In July a colleague clones the project —
but the lock is not there (somebody did not commit it). Simulate it:

    rm .terraform.lock.hcl
    rm -rf .terraform
    tofu init

Installing hashicorp/random v3.9.x: the latest the fence allows. Same
code, different date, different translator — drift is back, and this time
not on the servers: on the tools. The remedy is one: *the lock file gets
committed*, and whoever clones obtains the very same choice.

Honesty note: in *this* exercise repo the lock is gitignored — it exists
to let you run exactly the experiments you just ran. It is the exception
proving the rule: in a real project, the register goes into git.

### Cleanup

    tofu destroy

## Definition of done

- Phase 0's init failed with Unsupported OpenTofu Core version, and after
  TODO 1 it passed.
- In the lock file you spotted version, constraint and hashes.
- After TODO 2 (~> 3.5), init answered Reusing previous version ... from
  the dependency lock file, staying on 3.5.1.
- After init -upgrade the lock's diff shows the new version.
- Phase 4's conflict produced the error with the must use tofu init
  -upgrade indication.
- Without the lock (Phase 5), init installed the latest 3.x directly.
- You answered the three questions in answers.md.

## The three questions

**a.** The gate: from which team scenario does required_version protect
you, and why does it fire at init rather than at apply? And why are the
core constraint and the provider constraints two separate things (what
does the one pin, what do the others pin)?

**b.** The separation of powers: in Phases 2–4, who changed what? Explain
constraint-as-fence and lock-as-choice with the events you saw: why did
widening the fence move nothing, why did -upgrade move things, and why in
the conflict did the tool prefer stopping with an error over deciding by
itself? What exactly does ~> 3.5 promise, and why does the major stay
outside the fence?

**c.** The July colleague: what happened to him, and which single action
would have prevented it? What do the hashes add on top of plain
reproducibility? And can you explain why this exercise repo gitignores
the lock while your next real project must commit it?
