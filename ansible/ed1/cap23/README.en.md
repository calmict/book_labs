# Chapter 23 — The dress rehearsal

**Level:** Advanced

Chapter 22 taught you to *react* to errors. But the best way to handle an error is not to make it
— or at least to catch it *before* you touch production. Before a concert no orchestra walks on
stage blind: it re-reads the parts (is there a misprint?), holds a dress rehearsal in an empty
theatre (plays everything, no audience), and only then opens the doors. Ansible gives you the same
safety net, at three increasingly rich levels: --syntax-check (the quick read), ansible-lint (the
expert proofreader), and **check mode** with --diff (the dress rehearsal that shows you what would
change without changing it). Better a red error on your terminal than a silent breakage on a
thousand nodes.

## Objectives

- **Three levels of net**, cheapest to richest (23.1).
- The first step: **--syntax-check** (23.2).
- **ansible-lint**: the community's wisdom in one command — profiles, false positives (23.3).
- **Check mode**: the dress rehearsal in an empty theatre, with --diff (23.4).
- The **limits** of check mode, and how to work around them (23.5).
- Putting it all in order: the **validation flow** (23.6).
- The **good habits** with validation (23.7).

## Prerequisites

- The chapter 6 venv, plus **ansible-lint** (in start/requirements.txt).
- A playbook that "works but is sloppy": you clean it by putting it through the three levels.
- (No nodes: everything on the control node — connection: local — check mode and lint work where
  Ansible is.)

## The scenario

start/site.yml is a playbook that *runs*, but is full of small carelessnesses: unnamed play and
tasks, modules called by their short name, a badly written octal mode, commands that do not
declare whether they change anything. You put it through the three-level net and fix what each
level flags — until it is clean, predictable, and safe to send on stage.

Prepare the environment:

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    cd start

### Phase 1 — Three levels of net (23.1)

Three nets, cheapest to richest:

1. **--syntax-check**: reads the playbook and verifies it is *structurally* valid. Instant,
   touches nothing. It catches typos, not errors of judgement.
2. **ansible-lint**: applies hundreds of style and best-practice rules from the community. It runs
   nothing, but knows *a great deal*.
3. **check mode (--check --diff)**: the dress rehearsal — Ansible *simulates* the run and tells
   you what would change, without changing it.

The higher you go, the more the net costs and the more it catches. Use them *in this order*: stop
at the first one that fails. Question a.

### Phase 2 — The first step: --syntax-check (23.2)

    ansible-playbook --syntax-check -i localhost, site.yml

It reads the structure without connecting to any node: brackets, indentation, known keys. It is
the quick read before rehearsal — free, and it catches the gross errors in an instant.

### Phase 3 — ansible-lint: the expert proofreader (23.3 — TODO 1 and TODO 3)

    ansible-lint site.yml

Red cards rain on the sloppy playbook: name[play] (the play has no name), name[missing] (unnamed
tasks), fqcn (use ansible.builtin.copy, not copy), risky-octal (mode: 644 is ambiguous →
"0644"), no-changed-when (a command must say whether it changes anything). Complete **TODO 1**:
fix the playbook until ansible-lint passes.

**The profiles** (23.3) are the strictness dial: min, basic, safety, moderate, shared, production
— from "just the essentials" to "production-ready". Complete **TODO 3**: create a .ansible-lint
file that pins the project profile —

    profile: production

so anyone who runs ansible-lint (CI included) enforces the *same* level.

**False positives** happen: sometimes a rule is wrong about your case. You do not silence
everything — you silence *that line, with a reason*: # noqa: <rule> at the end of the task, or
skip_list in .ansible-lint. Silencing out of laziness is worse than the problem.

### Phase 4 — Check mode: the dress rehearsal (23.4 — --diff)

    ansible-playbook -i localhost, --check --diff site.yml

With **--check** Ansible does the empty-theatre rehearsal: it evaluates every task, says whether
it would be changed, but *writes nothing*. With **--diff** it shows you the exact lines that would
change:

    --- before
    +++ after
    @@ -0,0 +1,2 @@
    +mode = production
    +workers = 4

changed: [localhost] — and yet the file does not exist on disk yet. It is the difference between
knowing what a playbook will do and finding out *afterwards*. Question b.

### Phase 5 — The limits of check mode, and check_mode: false (23.5 — TODO 2)

The dress rehearsal has a limit: some things cannot be *simulated*. A command (command/shell) in
check mode is **skipped** — Ansible does not know what it would do, so it does not run it. But if
that command only *reads* a state (and its result guides the tasks that follow), skipping it makes
the rehearsal lie: the register variable stays empty, and the tasks that depend on it misbehave.

The remedy is to say "this task is safe, run it even in rehearsal": complete **TODO 2** on the
read task —

    - name: Read the current config (read-only, safe in check mode)
      ansible.builtin.command: cat {{ conf }}
      register: current
      changed_when: false
      check_mode: false

check_mode: false makes it run *always*: it really reads (it changes nothing), so check mode
downstream is accurate. Other limits remain — a task that depends on the *real* effect of an
earlier one (which in check did not happen) can mislead: check mode is a rehearsal, not reality.

### Phase 6 — The validation flow (23.6)

Lined up, the three levels are a funnel:

    ansible-playbook --syntax-check -i localhost, site.yml   # 1. structure (instant)
    ansible-lint site.yml                                     # 2. style and best-practice
    ansible-playbook -i localhost, --check --diff site.yml    # 3. what would change
    ansible-playbook -i localhost, site.yml                   # 4. ...and only now, for real

In CI it is the same ladder: the first three run on every push (they touch nothing), the fourth
only after approval. It is the "production gate" of chapter 26.

### Phase 7 — The good habits (23.7)

- **Bottom-up**: syntax-check first (free), lint next, check last. Do not reach the expensive one
  if the free one already stops you.
- **A declared profile** (.ansible-lint): strictness is a project decision, not a whim of whoever
  runs the command.
- **False positives with a reason**: a targeted # noqa, never a blanket global skip.
- **Check mode is a rehearsal, not a guarantee**: use check_mode: false for read tasks, and
  remember that what depends on real effects can lie in rehearsal.

## Done when

- --syntax-check passes on site.yml.
- ansible-lint passes on site.yml (TODO 1) at the production profile declared in .ansible-lint
  (TODO 3); and *fails* on the sloppy starting playbook.
- The read task has check_mode: false (TODO 2): it runs even under --check.
- --check --diff shows the diff of conf.txt but does *not* write the file; the real run writes it;
  on a rerun → changed=0.

## Questions to reflect on

**a.** The three levels (syntax-check, lint, check mode) cost and catch increasingly. Why does it
make sense to use them *in this order* and stop at the first that fails, instead of launching the
richest one straight away? What does each catch that the previous one cannot?

**b.** Check mode says "changed" but writes nothing. In what sense is it more than a plain "dry run
that prints the commands"? What does --diff give you that the changed/ok outcome alone would not,
and why does "seeing the lines that would change" change the way you review a playbook?

**c.** ansible-lint embodies "the community's wisdom" as rules. But sometimes a rule is a false
positive for your case. Why is the right answer a *targeted and justified* # noqa and not
disabling the rule for the whole project? What do you lose the day you silence a rule wholesale to
quiet a single task?

## Cleanup

Nothing to tear down: no nodes. The rendered conf.txt lands in /tmp/cap23-lab (or wherever
CAP23_LAB points); delete it if you like.

## Where it leads

You can *re-read* and *rehearse* a playbook before running it. But a clean lint and an
empty-theatre rehearsal do not prove that the role actually *works* on a real system, repeatedly,
from scratch. **Chapter 24** opens **Molecule**: the rehearsal with a real audience and a real
stage — it creates a throwaway environment, applies the role, verifies idempotence and the result,
and tears it all down. From re-reading the parts, to the full run-through.
