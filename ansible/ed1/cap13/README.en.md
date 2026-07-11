# Chapter 13 — The chain of command

**Level:** Intermediate

In chapter 12 you saw the command line beat group_vars, almost without thinking. It was
not magic: it was **precedence**. Ansible lets you define a variable in *many* places — a
huge convenience — but the price is that, when two places declare the same name with
different values, one must win. Ansible has a rigid **chain of command**: **22 levels**,
from the weakest (role defaults) to the strongest (-e). This chapter does not have you
build infrastructure: it has you *investigate*. You provoke real clashes between
variables, watch who wins, learn the three principles that explain almost everything, the
two pitfalls that surprise everyone, and how to design so as never to fight.

## Objectives

- **Why** so many levels exist (13.1).
- The **three principles** that explain almost everything (13.2).
- The **complete list**, from weakest to strongest (13.3).
- **Real clashes**: seeing it in action (13.4).
- The **tools** to not get lost (13.5).
- The **two pitfalls**: dictionaries that do not merge, and facts (13.6).
- **Designing** so as not to fight (13.7).

## Prerequisites

- The chapter 6 venv (or start/requirements.txt).
- The variables of chapter 12: group_vars, host_vars, -e, set_fact.
- (No nodes to power on: precedence is resolved on the **control node**, before anything
  touches a machine. The lab's two hosts are local.)

## The scenario

Two hosts, web1 and web2, with **local** connection — no SSH needed: we are studying *how
Ansible chooses a value*, and that choice happens entirely at home, on the control node.
You will define the same variable name in several places and use the debug module to print
**who won**.

## Step by step

### Phase 1 — Why 22 levels

Chapter 12 gave you the freedom to put a variable in the group, the host, the play, the
command line, the facts… Each place exists for a good reason: a team value belongs in
group_vars, a host's exception in its host_vars, a one-evening override in -e. But "many
places" means "many ways to say the same thing in disagreement". Ansible does not guess: it
orders *every* possible source on a fixed scale, and when two contradict, the higher one
wins. There are 22 places, so there are 22 levels.

### Phase 2 — The three principles that explain almost everything

You do not need to memorise 22 lines. Three principles get you 90% of the way:

1. **The extremes are absolute.** -e (extra vars) beats *everything*; role defaults lose
   to *everything*. No exceptions, ever.
2. **In between, the more specific you are the stronger you are** (usually). host beats
   group; a more specific group beats a more general one; a play, role or task variable
   beats an inventory one. An excellent intuition — but *not* a law without exceptions
   (Phase 6).
3. **At the same level, the last defined wins.** And for overlapping groups, ordering
   (group priority or, failing that, alphabetical) decides who has the last word.

### Phase 3 — The complete list, from weakest to strongest

When the intuition is not enough, this is the truth (ansible-core 2.15), from weakest (1)
to strongest (22):

    1  command line -u/... (connection, not variables)
    2  role defaults
    3  inventory: group vars in the file
    4  inventory group_vars/all
    5  playbook group_vars/all
    6  inventory group_vars/<group>
    7  playbook group_vars/<group>
    8  inventory: host vars in the file
    9  inventory host_vars/<host>
    10 playbook host_vars/<host>
    11 facts / cached set_facts
    12 play vars
    13 play vars_prompt
    14 play vars_files
    15 role vars (role/vars/main.yml)
    16 block vars
    17 task vars
    18 include_vars
    19 set_fact / registered vars
    20 role / include_role params
    21 include params
    22 extra vars (-e)  <-- always wins

### Phase 4 — Real clashes (TODO 1)

Open start/host_vars/web2.yml and complete **TODO 1**: give web2 its own conflicting
variables (winner, bad_limits, limits_override). Then run it and read the first clash, the
**specificity ladder**:

    ansible-playbook -i start/inventory.ini start/site.yml

    web1: winner = group_vars(web)     # web1 takes the group value (level 6)
    web2: winner = host_vars(web2)     # web2, more specific, wins (level 9)

Now the club of level 22:

    ansible-playbook -i start/inventory.ini start/site.yml -e winner=EXTRA

    web1: winner = EXTRA
    web2: winner = EXTRA               # -e beats even the host var

You have seen principle 1 and principle 2 live: host beats group, -e beats all.

### Phase 5 — The tools to not get lost

When "why does that value win?" drives you mad, two tools:

- **ansible-inventory --host web2**: shows you the variables the *inventory* attributes to
  web2 (group_vars + host_vars merged), without running anything.

      ansible-inventory -i start/inventory.ini --host web2

- **debug** where you use it: {{ }} resolved at the right moment is the final truth.
  Printing the variable *at the point* where you use it beats any abstract reasoning.

And remember: -vvv on the playbook shows where each value comes from.

### Phase 6 — The two pitfalls (TODO 2, TODO 3)

**Pitfall 1 — dictionaries do not merge.** In group_vars, bad_limits has two keys; in
host_vars, web2 redefines *only one*. What happens to web2?

    web1: bad_limits keys = ['max_connections', 'timeout_seconds']
    web2: bad_limits keys = ['max_connections']     # timeout_seconds GONE

The higher level **replaces the whole dictionary**, it does not merge it: the key you did
not repeat is lost. It is the most common silent bug with structured variables. The cure is
**combine**. Complete **TODO 2** in the playbook — instead of overriding bad_limits, keep
the override in a separate variable (limits_override) and merge it explicitly:

    merged = {{ limits | combine(limits_override | default({})) }}

    web1: merged = {'max_connections': 200, 'timeout_seconds': 30}
    web2: merged = {'max_connections': 500, 'timeout_seconds': 30}   # timeout kept

**Pitfall 2 — facts pull from two opposite ends.** *Gathered* facts (Gathering Facts) sit
at level 11: **weak**, any play var with the same name silently beats them. But **set_fact**
sits at level 19: **very strong**. Complete **TODO 3**: pin mode with set_fact and try to
"lower" it with a task var (level 17):

    web2: mode = set_fact_value     # the task var is ignored: 19 beats 17

The same apparent mechanism ("a fact"), opposite ends of the scale: this is where the
"more specific wins" principle betrays you, and you must return to the list.

### Phase 7 — Designing so as not to fight

The best precedence is the one you never have to resolve:

- **One home per value.** If a name lives in a single place, there is no clash to win.
- **-e sparingly.** It is the level-22 sledgehammer: it beats everything, so it masks any
  other setting. Great for an emergency override, terrible as a habit.
- **Distinct names** for distinct things: half of all clashes come from two different
  variables that, by accident, share a name.
- **combine for the dictionaries** you really want to merge; never trust automatic merging
  (there is none, except hash_behaviour=merge, discouraged).
- **Do not lean on level tricks**: "my task var will surely win" is a bet a colleague's
  set_fact will make you lose.

## Done when

- **winner**: web1 = group_vars(web), web2 = host_vars(web2); with **-e** → EXTRA on both.
- **bad_limits**: web1 has 2 keys, web2 has 1 (the dictionary was replaced, not merged).
- **combine**: the merge gives web2 {max_connections: 500, timeout_seconds: 30} (timeout
  kept).
- **set_fact**: mode stays set_fact_value even with a task var (19 beats 17).

## Questions to reflect on

**a.** The three principles take you far, but set_fact (level 19) beats a task var (level
17), breaking "the more specific wins". Why does the *list*, not the intuition, ultimately
command? Describe a case where trusting the intuition alone would make you misdiagnose.

**b.** Ansible **replaces** dictionaries instead of merging them. Why is this behaviour
more predictable than automatic merging (which does exist, as hash_behaviour=merge,
discouraged)? List the ways to *really* merge two dictionaries and say which you prefer.

**c.** -e wins at level 22, above everything. Why use it sparingly, and not as a daily
shortcut? And what is the single design rule that, on its own, eliminates most "why does
*that* value win?" questions?

## Cleanup

Nothing to tear down: this chapter powers no nodes.

## Where it leads

You know who wins when variables clash — and how not to make them clash. Chapter 14 changes
the subject and returns to action: **tasks, handlers and notifications**. There the
*changed* colour of chapter 5 becomes a signal that *triggers* something — a service that
restarts only if its configuration really changed — with notify and listen.
