# Chapter 21 — The pyramid of checks

**Level:** Cloud Architect
**Estimated time:** 50–60 minutes
**Manual topics:** the validation pyramid (21.1), the base: fmt and validate (21.2), security scans: policy as code (21.3), terraform test: verifying behaviour (21.4)

## The idea

An architect does not hand over a design because it "looks right": they run it
through a ladder of checks, from the cheapest and most frequent to the most
expensive and rare. It is the **validation pyramid**, and it has four floors.

At the *base*, wide and instant, two checks you run constantly: **fmt** verifies
the drawing is legible (the form), **validate** that it is internally consistent
(references resolve, types match). They cost milliseconds; you run them on every
save.

On the middle floor, the **security scans** — *policy as code*: rules written
once that automatically reject dangerous configurations (an unpinned image, a
port open to the world, a secret in plain text). They ask you to apply nothing:
they read the plan and say yes or no.

At the *top*, narrow and slower, the check of **behaviour**: tofu test. Not "is
the code well written?", but "does the code do the right thing?". You give inputs,
and check that the outputs, the planned resources, even the *rejections* of the
validations are the ones you expect. It is the real inspection — and like all real
inspections, you write it.

The pyramid's rule: many cheap checks at the base, few expensive inspections at
the top. In this chapter you walk them all, and write your first infrastructure
tests.

## Goals

By the end you will be able to:

- describe the validation pyramid and why it has that shape;
- use fmt and validate as an instant safety net (the base);
- recognise a policy-as-code rule and what it rejects (the middle floor);
- write behaviour tests with tofu test: run, assert, expect_failures;
- watch a test *reject* a regression — the reason tests exist.

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md.
- Docker running. Free port: 8130.
- Chapters 14 (variable validation) and 6 (fmt, validate): here they become a
  pyramid.

## Your task

### Phase 0 — The base: fmt and validate (21.2)

In start/ there is the configuration to inspect: a container with a validated
environment variable and a few derived outputs. Start from the base's two checks:

    cd start
    tofu init
    tofu fmt -check
    tofu validate

fmt -check changes nothing: it just tells you if the form is fine (silence =
everything formatted). validate checks internal consistency without touching
reality: references, types, arguments. They are the two rungs that cost least and
catch the most silly mistakes: always run them, first.

### Phase 1 — The middle floor: policy as code (21.3, reading)

Above the base are the security scans. Tools like tfsec, trivy, checkov or
conftest/OPA read your plan and compare it against rules written once and for all
— *policy as code*. In start/policy.rego.example you find an example to read: a
rule that rejects unpinned images (nginx:latest instead of nginx:1.27-alpine),
because a moving tag makes your deploy non-reproducible. The start configuration
passes that rule (the image is pinned); the point is that the rule runs *by
itself*, in CI, and stops whoever breaks it without needing a human review. No
scanner is installed in this lab: the phase is reading, but the concept —
executable rules, not hoped-for conventions — is the heart of the middle floor.

### Phase 2 — The top: writing tests (21.4, TODO 1 and 2)

Now the real inspection. In start/tests.tftest.hcl there is the skeleton of a
test suite. A .tftest.hcl file is made of run blocks, each a case: it fixes
variables, runs a command (plan or apply) and checks assert blocks. Complete the
two TODOs.

TODO 1 is inside run "plan_defaults": complete the assert that checks the url
output. With environment = dev and the default port, it must hold:

    assert {
      condition     = output.url == "http://localhost:8130"
      error_message = "the url output should use the default port"
    }

TODO 2 is a subtler case: verifying that chapter 14's validation *rejects* a bad
input. You do not check an output — you check that the plan *fails*, on the right
variable. Complete the run "rejects_bad_environment" block:

    run "rejects_bad_environment" {
      command = plan
      variables {
        environment = "banana"
      }
      expect_failures = [
        var.environment,
      ]
    }

expect_failures inverts the logic: the test passes *because* the plan fails, on
the expected variable. Run the suite:

    tofu test

Read the pyramid in action: each run "... pass", and at the bottom Success! N
passed, 0 failed. The third run, unlike plan_defaults, really applies and checks
the real container's name — the inspection that touches reality.

### Phase 3 — Why tests exist: rejecting a regression

A test that always passes proves nothing. Change one line of the configuration to
introduce a bug — for example, in main.tf, derive the name from something wrong
(change the local container_name to "cap21-fixed"). Run again:

    tofu test

Now the inspection rejects it: Test assertion failed, and it shows you the real
value against the expected one, then Failure! The test did its job — it stopped a
change that broke the behaviour, before it reached production. Put the line back
and check it goes green again.

### Phase 4 — The bridge (reflect)

You have four floors of checks: form (fmt), consistency (validate), security
(policy), behaviour (test). On their own they are worth little: their place is
*automatic*, on every commit, before the code touches production. It is exactly
chapter 22 — CI/CD and GitOps: the pyramid that fires by itself, and the
repository as the single source of truth.

### Cleanup

    # tofu test cleans up the resources it creates by itself; just in case:
    docker rm -f cap21-dev 2>/dev/null

## Definition of done

- fmt -check and validate passed on the start configuration.
- You recognised, in the policy example, which configuration would be rejected
  (an unpinned image) and why.
- After TODO 1 and 2, tofu test gave Success! with all runs green, including the
  one with expect_failures.
- Breaking the name in Phase 3, tofu test failed with Test assertion failed, and
  went green again once restored.
- You answered the three questions in answers.md.

## The three questions

**a.** The pyramid's shape: why do fmt and validate sit at the base (many, often)
and tofu test at the top (few, rare)? What does each of the four floors catch that
the one below does not — give an example of an error only a behaviour test can
catch.

**b.** expect_failures: in TODO 2 the test passes *because* the plan fails. Why is
testing that something is *rejected* as important as testing that something works?
Connect it to chapter 14's validation: what exactly do you prove with that run?

**c.** Policy as code and the bridge: what is the difference between a *convention*
("remember to pin images") and a *policy as code* (the example's Rego rule)? Why
does the pyramid give its best only when it runs automatically on every commit —
what changes compared to running it by hand?
