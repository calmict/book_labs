# Chapter 6 — Answers

## init, under the lens (Phase 2)

    # paste here the provider binary path and size (the find/du line):

    # how long did the SECOND init take?

## The saved plan (Phase 3)

    # paste the last line printed by: tofu plan -out=first.plan

    # did tofu apply first.plan ask for confirmation? (yes/no)

## The three everyday commands (Phase 4)

    # paste the output of: tofu state list

## After the destroy (Phase 6)

    # paste the output of: ls -a   (what survived the demolition?)

## The three questions

**a. Two binaries, one language — and two installations.**

_(4-6 lines: what you installed, what init installed and where, why the
split makes sense, and what would change with terraform instead of tofu)_

**b. The saved plan: a contract that asks no questions.**

_(4-6 lines: what the file is, why no confirmation is needed, and why
exactness matters between review and execution)_

**c. The three everyday questions, and the destroy asymmetry.**

_(4-6 lines: match state list / show / output to their questions, why
other people's containers are invisible, what destroy left behind)_
