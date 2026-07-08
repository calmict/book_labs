# Chapter 5 — The switch and the doorbell

**Level:** Foundational

In chapter 1 you saw the difference between "re-runnable" and "convergent". Now we
take it to the core: **idempotence**. A light switch is idempotent — you flip it to
ON; if it is already ON, nothing happens, and the room is lit either way. A doorbell
is not: every press rings again. Ansible is made of **switches**: you tell it the
desired *state*, it acts only if needed, and it tells you the **colour** of the
change. Before installing it (chapter 6), you build it in miniature with your own
hands: a tiny idempotent engine in bash that reports the colours and can do a "dry
run".

## Objectives

- **Idempotence** without fear: applying twice = applying once.
- **Switch vs doorbell**; **declarative vs imperative**.
- The **colours** of change: ok (green, nothing to do), changed (yellow, I acted),
  failed (red).
- The **black swans**: operations that are not idempotent by nature, and how to
  judge them (changed_when).
- The **dress rehearsal**: check mode (dry-run) and diff.

## Prerequisites

- bash. Nothing else — and for the last time **no Ansible**: this is the chapter that
  closes the "before". From chapter 6 you install it.

## The scenario

A small engine that brings a piece of the system to its **desired state** and tells
you, for each operation, what colour it was: green if it was already correct, yellow
if it had to act.

## Step by step

### Phase 1 — The colours, twice

The engine brings the system to a state (a line in a config file). Run it on an empty
state, then again:

    bash solution/ensure.sh /tmp/cap05-state
    bash solution/ensure.sh /tmp/cap05-state

First run: everything [changed] (yellow) — it acted. Second run: [ok] (green) —
nothing to do. **This is idempotence**: the second time it does nothing, and it
*says so*. An automation that can say "ok, it was already like this" is one you can
re-run a thousand times without fear.

### Phase 2 — TODO 1: the switch

In start/ensure.sh the heart of ensure_line is missing. Implement the switch logic:
**if the line is already there → ok; otherwise add it → changed**. Flipping to ON
twice leaves it ON:

    if the line is already in the file:  report ok
    otherwise:                           add the line, report changed

### Phase 3 — The doorbell, for contrast

The engine also has append_line, which **always appends**. See the difference by
running it twice: it stays [changed] every time, the file grows, it never converges.
It is a **doorbell**: every press rings again. In a word: append_line says *how*
("append"), ensure_line says *what* ("make sure it is there"). Imperative vs
declarative.

### Phase 4 — TODO 2: the dry run (check mode)

Add CHECK=1 support to ensure_line: in check mode it must report that it **would**
change, without writing anything.

    bash solution/ensure.sh /tmp/cap05-fresh            # actually applies
    CHECK=1 bash solution/ensure.sh /tmp/cap05-fresh2    # says what it WOULD do, touches nothing

It is Ansible's --check: the dress rehearsal on an empty stage. You see what would
change *before* changing it.

### Phase 5 — TODO 3: the black swan and changed_when

Some operations run **every time** (rendering a template, launching a shell command):
their "it worked" (exit 0) does not say whether anything actually *changed*. The
render function always writes; complete the **changed_when** rule: judge "changed" by
comparing the content **before** and **after**, not by the exit code.

    render always writes
    then: if (before == after)  report ok       # nothing changed, even though the command ran
          otherwise             report changed

That way, with the same inputs, the second run is [ok], not [changed]. Without this
rule, a black swan would stay yellow forever — a false "changed" on every run.

### Phase 6 — The red, and failed_when

The third colour is **failed** (red). But even "failed" sometimes lies: grep exits 1
when it *does not find* — that is not an error, it is an answer. In Ansible,
failed_when lets you redefine what counts as a failure, exactly as changed_when
redefines what counts as a change. The chapter's moral: **the exit code is a clue,
not the truth** — it is you (or the well-written module) who decides the colour.

## Done when

- ensure.sh completed: **first run all [changed], second run [ok]** (idempotence).
- The doorbell append_line stays [changed] on every run (never converges).
- In **check mode** ensure_line says [changed] WOULD but **writes nothing**.
- render with changed_when reports [ok] on the second run with the same inputs.

## Questions to reflect on

**a.** Define idempotence in your own words and explain why it is what makes an
automation **safe to re-run** (connect it to chapter 1: re-runnable vs convergent).

**b.** Why is a shell command a "**black swan**" for an idempotent engine, and what
do you give it with changed_when so it stops lying about the colour?

**c.** Check mode has a limit: if task B depends on the *effect* of task A (A creates
something B will use), in a dry run what can you **not** predict about B's result?

## Cleanup

    rm -rf /tmp/cap05-state /tmp/cap05-fresh /tmp/cap05-fresh2

## Where it leads

In chapter 6 you install Ansible and discover that every **module** is already a
switch: it reports the colours, supports --check, and gives you
changed_when/failed_when for the black swans. You built the engine by hand; from here
on you use the real one — and you know exactly what it does underneath.
