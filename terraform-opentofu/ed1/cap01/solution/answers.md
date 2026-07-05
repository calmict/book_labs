# Chapter 1 — Answers (model solution)

## The click-ops drift (Phase 0)

    1,2c1,2
    < hostname = web-01
    < packages = nginx, openssl
    ---
    > hostname = web-02
    > packages = nginx
    4c4
    < debug_mode = off
    ---
    > debug_mode = on

(the hostname difference is intentional; the missing package and the debug
flag are not — that is the drift)

## Idempotence (Phase 2)

    No changes. Your infrastructure matches the configuration.

## The sabotage, converged (Phase 3)

    debug_mode = off

## The herd tags (Phase 5)

    # herd_tag before destroy:  saved-owl
    # herd_tag after re-apply:  immense-chipmunk
    # (yours will differ — the point is that they differ from each other)

## The three questions

**a. Why does click-ops produce snowflakes by its very nature, and why is an
imperative script, by itself, not enough?**

Click-ops depends on a human replaying a sequence of manual actions from
memory, and humans never replay anything exactly: a forgotten package, a flag
left on, a different order of steps. The drift you saw was not caused by
months of entropy — it was baked in at creation, because the "procedure"
lived in someone's head. An imperative script freezes the steps, which is
better, but it still describes HOW, not WHAT: run it twice and it either
re-executes actions that must not happen twice or crashes halfway, leaving
the server in a state the script never contemplated. It has no idea of the
current state and no notion of "already done" — that is exactly the missing
piece: idempotence.

**b. What did you describe in main.tf, and what did you never write? What
does the tool do for you, and what stays outside its job?**

The file describes only the desired RESULT: one mould and two files that must
exist with that content and those permissions. Nowhere did we write the
steps — no "create the directory", no "check whether the file exists", no
"overwrite if different". Deciding which actions are needed to go from
current reality to the model (create, re-create, do nothing) is precisely the
tool's job: it compares state and configuration and computes the plan. What
stays outside its mission is everything that happens INSIDE a real server
once it exists — installing packages, tuning services, deploying the app.
Terraform provisions the infrastructure; configuring its guts is the trade of
other tools (configuration managers like Ansible), or of immutable images
built beforehand.

**c. Why is a changing identity acceptable — indeed an advantage — for
cattle, and why would it not be for a pet?**

The herd_tag changed from one generation to the next, and nothing of value
was lost: everything that matters about those servers lives in the mould, so
a new tag is just a new label on an interchangeable head of cattle. That is
the cattle property: identity is disposable BECAUSE the configuration is
fully reproducible from code — and it is an advantage, since replacing is
cheaper and safer than repairing (as Phase 3 showed: re-cast, not patch). A
pet is the opposite: its identity IS its value, an accumulation of
undocumented hand edits that exist nowhere but on that machine. Destroy a
pet and no apply will ever bring it back — which is why pets make teams
afraid of their own servers, and cattle make destroy just another command.
