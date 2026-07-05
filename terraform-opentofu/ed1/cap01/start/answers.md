# Chapter 1 — Answers

## The click-ops drift (Phase 0)

    # paste here the output of:
    # diff server-a.conf server-b.conf

## Idempotence (Phase 2)

    # paste here the exact line tofu printed on the second apply

## The sabotage, converged (Phase 3)

    # paste here the output of:
    # grep debug servers/server-b.conf   (after the apply)

## The herd tags (Phase 5)

    # herd_tag before destroy:
    # herd_tag after re-apply:

## The three questions

**a. Why does click-ops produce snowflakes by its very nature, and why is an
imperative script, by itself, not enough?**

_(4-6 lines: connect what you saw in Phase 0 to drift at creation time, and
think about what happens when a script is re-run on a half-configured server)_

**b. What did you describe in main.tf, and what did you never write? What
does the tool do for you, and what stays outside its job?**

_(4-6 lines: think about the missing "steps", and about what happens inside a
real server after it exists)_

**c. Why is a changing identity acceptable — indeed an advantage — for
cattle, and why would it not be for a pet?**

_(4-6 lines: use the herd_tag as your example)_
