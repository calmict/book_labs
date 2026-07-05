# Chapter 1 — The snowflake and the herd

**Level:** Foundational
**Estimated time:** 30–40 minutes
**Manual topics:** the click-ops crisis and the snowflake server (1.1), from scripts to managed configuration (1.2), what Terraform does and does not do (1.3), pets and cattle (1.4)

## The idea

Before learning the syntax, you need to *feel* the problem. In this exercise
you build two "servers" by hand, the way it used to be done (and sadly still
is) with click-ops: you will find they diverge immediately. Then you describe
them as code: the same snapshot of the result for both. From there on you
torture the infrastructure — you hand-edit it in the middle of the night, you
delete a piece of it, you raze it to the ground — and every time a single
command brings it back exactly to the model. By the end, a "server" is no
longer a pet with a name and a personal history: it is a head of cattle with
a tag, replaceable at any moment.

The "servers" here are plain configuration files on your disk: zero cloud,
zero cost, but the concepts — drift, idempotence, convergence, immutable
identity — are exactly the ones you will meet in production.

## Goals

By the end you will be able to:

- recognise configuration drift and explain why click-ops inevitably
  produces it;
- tell the imperative approach ("run these steps") from the declarative one
  ("this is the result I want");
- watch idempotence in action: applying twice changes nothing;
- see convergence: hand-modified reality returns to the model;
- explain the difference between pets and cattle with a concrete example.

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md in the manual folder. The
  commands below use tofu; with terraform they are identical.
- No HCL knowledge required: the syntax arrives in chapters 5 and 6. Here you
  read it guided by the comments — you do not need to write it yet.

## Your task

### Phase 0 — Click-ops, like the old days

You are Monday's sysadmin. Create the first server by hand:

    mkdir -p /tmp/clickops && cd /tmp/clickops
    printf 'hostname = web-01\npackages = nginx, openssl\nport = 8080\ndebug_mode = off\n' > server-a.conf

On Tuesday a colleague has to create the "twin". In a hurry, copying from
memory:

    printf 'hostname = web-02\npackages = nginx\nport = 8080\ndebug_mode = on\n' > server-b.conf

Compare them:

    diff server-a.conf server-b.conf

Two "identical" servers that were never identical: a package is missing,
debug was left on. This is drift, and it was born at *creation* time, not
after months. Every hand-made server is a snowflake: unique, fragile,
unrepeatable.

### Phase 1 — Describe the result, not the steps

Enter the exercise folder and open start/main.tf. You will find the mould
(the golden configuration, the same for everyone) and the first server
already declared. The TODO asks you to declare the second server using **the
same mould**: no copying from memory, no drift possible by construction.

Once the TODO is done:

    cd start
    tofu init
    tofu apply

Read the plan it proposes before confirming: it is the difference between the
model (two servers) and reality (zero servers). Then verify:

    diff servers/server-a.conf servers/server-b.conf

No difference. One mould, identical casts.

### Phase 2 — Idempotence

Apply again, having changed nothing:

    tofu apply

Look at the answer. A second run of an imperative script would have re-run
every step (or blown up); here instead nothing happens, *because nothing has
to happen*: reality already matches the model.

### Phase 3 — The night-time sabotage (drift)

It is 03:12 and somebody "quick-fixes" a server in production:

    printf 'debug_mode = on   # temporary fix, will remove it later (a lie)\n' >> servers/server-b.conf

Ask for the plan:

    tofu plan

Look closely: the hand-modified file is not "patched" — to the provider that
mutant is no longer the resource it was managing, and the plan proposes to
re-create it from the mould. This is immutability in miniature: you do not
repair the snowflake, you re-cast it from the model. Converge:

    tofu apply
    grep debug servers/server-b.conf

Debug is off again. The 03:12 "temporary fix" does not survive the first
apply: the source of truth is the code, not the memory of whoever intervened
at night.

### Phase 4 — The disappearance

Delete a server entirely:

    rm servers/server-a.conf
    tofu plan

The plan proposes to re-create it, identical. Apply and verify.

### Phase 5 — The herd

Take note of your herd's tag:

    tofu output herd_tag

Then raze everything and rebuild:

    tofu destroy
    tofu apply
    tofu output herd_tag
    cat servers/server-a.conf

The configuration is back, identical in every line that matters, but the tag
is different: it is another head of cattle, and that is perfectly fine. Had
web-01 been a pet — with years of undocumented hand edits — this operation
would have been an irreversible catastrophe. Here it is one command.

### Cleanup

    tofu destroy

## Definition of done

- Phase 2 answers exactly: No changes. Your infrastructure matches the
  configuration.
- After the Phase 3 sabotage, one apply brings debug_mode back to off without
  you touching the file by hand.
- After destroy + apply (Phase 5) both files exist again, identical to each
  other, with a herd_tag different from the one you noted down.
- You answered the three questions in answers.md.

## The three questions

Answer in your own words in answers.md (the template is in start/):

**a.** In Phase 0 drift appeared at the servers' *creation*, not after months
of life. Why does click-ops produce snowflakes by its very nature, and why is
an imperative script, by itself, not enough to eliminate the problem?

**b.** What did you *describe* in main.tf, and what did you never write
anywhere? In that light: what does the tool do for you, and what stays
outside its job (think about what happens *inside* a real server after it
exists)?

**c.** In Phase 5 the herd was reborn with a new tag and nobody worried.
Explain the difference between pets and cattle using the herd_tag itself as
the example: why is a changing identity an acceptable price — indeed an
advantage — for cattle, and why would it not be for a pet?
