# Chapter 21 — Answers (model solution)

## The base (Phase 0)

    # tofu fmt -check: (silence) — the form is fine
    # tofu validate: Success! The configuration is valid.

## The tests (Phase 2)

    run "plan_defaults"... pass
    run "rejects_bad_environment"... pass
    run "apply_creates_container"... pass
    Success! 3 passed, 0 failed.

## Rejecting a regression (Phase 3)

    Error: Test assertion failed
      local.container_name is "cap21-broken"
    Failure! ... failed.
    # (fmt and validate stay green on the broken config — only the test sees it)

## The three questions

**a. The pyramid's shape.**

fmt and validate sit at the base because they are cheap and fast — milliseconds,
no state, no provider round-trips — so you run them constantly, on every save and
every commit; they catch the largest class of trivial errors (bad formatting,
undefined references, wrong types) at the lowest cost. tofu test sits at the top
because it is expensive: it plans, sometimes applies real resources, and takes
seconds to minutes, so you run fewer of them, less often. Each floor catches what
the one below cannot: fmt catches only form; validate catches internal
consistency but not whether the values are RIGHT; a policy scan catches dangerous
patterns (an unpinned image) that are perfectly valid HCL; and a behaviour test
catches wrong behaviour that is valid, consistent, and policy-clean. An example
only a test catches: a refactor that changes the derived container name from
cap21-dev to cap21-broken — the file still formats, validates and passes every
policy, but the service now comes up under the wrong name. Only an assert on the
actual value sees it.

**b. expect_failures.**

Testing a rejection matters as much as testing success because half of correct
behaviour is refusing the wrong input. A validation block (chapter 14) is a
promise: "this variable only accepts dev, staging, prod". If that promise
silently broke — someone widens the condition, or deletes the validation — no
success test would notice, because the happy path still works. The
expect_failures run pins the promise down: it feeds environment = "banana" and
asserts the plan FAILS on var.environment. The test passes precisely because the
bouncer did its job. What I prove with that run is that the guard is still there
and still guarding the right thing — that the door I built in chapter 14 has not
quietly come off its hinges.

**c. Policy as code and the bridge.**

A convention ("remember to pin images") is a hope written in a wiki: it depends on
every person remembering, every time, and on a reviewer catching the lapse — it
fails silently and often. A policy as code (the Rego rule) is the same intent made
executable: a machine reads the plan and returns deny with a reason, the same way
for everyone, every time, with no memory and no mood. The pyramid gives its best
only when it runs automatically on every commit because that is what turns all
four floors from advice into a gate: run by hand, they catch what you remember to
run and skip what you are in a hurry to skip, exactly when haste makes mistakes
likely; run automatically, they block the merge before a human even looks. Running
by hand is a suggestion; running on every commit is a wall — and that wall is
chapter 22.
