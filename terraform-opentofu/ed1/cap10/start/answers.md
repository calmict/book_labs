# Chapter 10 — Answers

## Read during the plan (Phase 1)

    # paste the Reading.../Read complete lines from the plan:

    # paste the netcard content AS SHOWN IN THE PLAN (already resolved):

## Building on someone else's ground (Phase 2)

    # paste the docker inspect line showing network and IP:

## The two fates (Phase 3)

    # from the SAME plan: netcard content vs freshcard content —
    # which one is (known after apply), and why?

## Reading is not owning (Phase 4)

    # paste the data. entries from tofu state list:

    # after the destroy: is cap10-platform-net still in docker network ls?

## The three questions

**a. Reading vs owning.**

_(4-6 lines: resource imposes, data queries; the data. entries in state;
what destroy did and did not touch)_

**b. Rule 10.5 in one plan.**

_(4-6 lines: the general rule for plan-time vs apply-time reads, and why
it matters for reviewing plans)_

**c. The bridge to chapter 11.**

_(3-5 lines: where the tool remembers what it read, and what the next
plan would do if the platform's network changed)_
