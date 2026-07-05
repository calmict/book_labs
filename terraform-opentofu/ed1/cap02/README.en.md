# Chapter 2 — The recipe and the photograph

**Level:** Foundational
**Estimated time:** 40–50 minutes
**Manual topics:** the imperative model: thinking in steps (2.1), the declarative model: describing the result (2.2), idempotence (2.3), convergence (2.4), when imperative remains the right choice (2.5), why this split prepares immutability (2.6)

## The idea

A recipe lists the steps: crack the eggs, heat the pan, pour. A photograph
shows the finished dish. In chapter 1 you *felt* the drift; here you put your
hands on the split that generates it: you actually write an imperative
provisioning script, watch it blow up on the second run, repair it by adding
guards ("if it exists, skip") — and then discover its fatal flaw: guards make
the script re-runnable, but *blind*. A vandalised file walks past the guard
undisturbed, because the guard checks that the file *exists*, not that it is
*right*.

Then you photograph the same fleet in a main.tf and torture it from four
different starting points — empty yard, half-built, vandalised, already
finished — always with the same identical command. You no longer write the
steps: the tool computes them, every time, by comparing reality with the
model.

## Goals

By the end you will be able to:

- explain why a script of steps only works from the starting point its
  author had in mind;
- build idempotence by hand with guards, and measure its cost;
- tell re-runnability from convergence: guards buy you the first, not the
  second;
- watch the same command produce different plans from different starts, and
  the same result from all of them;
- recognise the tasks for which the recipe remains the right tool.

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md. The commands use tofu;
  with terraform they are identical.
- Basic bash (you know what mkdir and an if do). The HCL is read guided by
  the comments, as in chapter 1.

## Your task

### Phase 0 — The recipe, first run

In start/ you will find provision.sh: ten imperative lines that create a
fleet of three servers (configuration files) and register it in an inventory.
Read it: it is clear, tidy, and it works.

    cd start
    ./provision.sh
    ls fleet/

All there: three configs and an inventory.txt. Now run it again:

    ./provision.sh

It blows up at the first step: the directory already exists. The script is
not wrong — it is *imperative*: it describes the steps from ONE precise
starting point (emptiness). From any other starting point, the steps make no
sense.

### Phase 1 — The guards (hand-made idempotence)

Open provision.sh: the TODOs point at the three spots to protect. Make the
script re-runnable: create the directory only if missing, write each config
only if it does not exist, register the inventory only once. (Hints in the
comments: mkdir -p, if [ -f ... ].)

When you are done:

    ./provision.sh
    ./provision.sh

Two runs, zero errors: "already exists, skipping" everywhere. Congratulations,
you built idempotence by hand. Note how much code it took: the script nearly
doubled, and every future resource will have to carry its own guard.

### Phase 2 — The blind guard

It is 03:12 again, and somebody touches a server by hand:

    sed -i 's/debug_mode = off/debug_mode = on/' fleet/server-2.conf

Re-run the script you just repaired:

    ./provision.sh
    grep debug fleet/server-2.conf

Look closely: "server-2 already exists, skipping" — and debug is still on.
The guard did exactly its job: the file *exists*, so it skips. It never
looked *inside*. Re-runnable does not mean convergent: to truly converge you
would have to compare the content of every file with the desired content —
that is, rewrite in bash, by hand, what a declarative tool does for a living.

### Phase 3 — The photograph

Raze the recipe's yard and switch to the model:

    rm -rf fleet

Open main.tf: the same fleet, but described as a result — three servers cast
from the same mould and an inventory *derived from the model* (look at the
join: the list of servers writes the inventory itself, neither can forget the
other). The TODO asks you to declare server_3, following the first two. Then:

    tofu init
    tofu apply

### Phase 4 — Four starting points, one command

Now torture the photograph. Vandalised start:

    sed -i 's/debug_mode = off/debug_mode = on/' fleet/server-2.conf
    tofu plan
    tofu apply
    grep debug fleet/server-2.conf

The drift the guard skipped is seen here (the plan proposes to re-cast the
mutant) and absorbed. Half-built start — exactly the state where the naive
recipe crashed:

    rm fleet/server-3.conf
    : > fleet/inventory.txt
    tofu plan
    tofu apply
    cat fleet/inventory.txt

This time the plan says two resources, not one: it re-creates only what is
missing or deviating. Already-complete start:

    tofu apply

No changes. Four starting points, one identical command, all different plans,
always the same result: this is convergence. The steps still exist — but the
tool computes them, every time, from the comparison between reality and the
model.

### Cleanup

    tofu destroy

## Definition of done

- The repaired provision.sh survives two consecutive runs without errors.
- After the Phase 2 sed, the guarded script LEAVES debug on (this is the
  expected behaviour: it is the demonstration, not a bug).
- From the half-built start, tofu plan proposes exactly 2 resources to
  re-create, and after the apply the inventory lists the three servers again.
- The last apply answers: No changes.
- You answered the three questions in answers.md.

## The three questions

**a.** Why did the naive recipe blow up on the second run, and what —
exactly — did the guards add, and what did they not? Use the vandalised
server-2 to tell *re-runnability* from *convergence*.

**b.** Across the four starting points the command was always the same, but
the plans differed (4 to create, 1, 2, none). Who computes the steps now, and
from which *two* ingredients? What did you stop having to know?

**c.** When does the recipe remain the right choice? Give two concrete
examples of tasks you would never describe as a photograph (think: a
timestamped backup, a one-shot migration, a reboot). And why does this split
prepare chapter 3's immutability — in chapter 1 the mutant was not repaired
but re-cast: which of the two models makes that gesture natural?
