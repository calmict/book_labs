# Chapter 7 — Answers

## The closed gate (Phase 0)

    # paste the error title printed by tofu init:

## The register's birth (Phase 1)

    # paste from .terraform.lock.hcl: the version line, the constraints
    # line, and ONE hash line

## The fence and the choice (Phase 2)

    # paste the init line proving the lock won over the widened fence:

## The deliberate gesture (Phase 3)

    # paste the version lines from: diff lock.before .terraform.lock.hcl

## The conflict (Phase 4)

    # paste the error's last line (the one suggesting the way out):

## The July colleague (Phase 5)

    # which version did init install without the lock?

## The three questions

**a. The gate: which team scenario, why at init, and why two separate
kinds of constraint?**

_(4-6 lines: the colleague with the old binary; what required_version
pins versus what provider constraints pin)_

**b. The separation of powers: fence versus choice.**

_(4-6 lines: use Phases 2-4 — the widened fence that moved nothing, the
-upgrade that moved things, the conflict where the tool refused to choose;
plus what ~> 3.5 promises and why majors stay out)_

**c. The July colleague, the hashes, and where the lock belongs.**

_(4-6 lines: the missing commit, integrity on top of reproducibility, and
why this exercise repo is the exception)_
