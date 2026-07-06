# Chapter 3 — Answers

## The renovation (Phase 1)

    # container ID before the apply:
    # container ID after the apply:
    # the plan title line for the memory change:

## The reconstruction (Phase 2)

    # paste 2-3 plan lines carrying the "# forces replacement" marker

    # the announced order (the line next to -/+):

## The flipped order (Phase 3)

    # the announced order now (the line next to +/-):

## The safety catch (Phase 4)

    # paste the error line printed by tofu destroy:
    # and the error when you only bumped the version and asked for a plan:

## The three questions

**a. Which attribute travelled in-place and which forced the replacement?
How did you know before applying, and why does the provider decide?**

_(4-6 lines: name the plan signage — tilde, -/+, the marker — and think
about what the docker API can and cannot change on a living container)_

**b. What made create_before_destroy possible here, and what would a fixed
name have caused? What does prevent_destroy block — and not block?**

_(4-6 lines: identity contention on one side; plan-driven destroys and
replacements versus hand deletions on the other)_

**c. Why does rebuilding reduce risk compared to renovating, and what is
still missing from the picture?**

_(4-6 lines: the snowflake's accumulated history, rollback as just another
replacement, and the ordering question that chapter 4 answers)_
