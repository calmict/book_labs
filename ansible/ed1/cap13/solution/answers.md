# Chapter 13 — Answers (model solution)

## The completed TODOs

    # TODO 1 — host_vars/web2.yml: stage the clashes
    winner: host_vars(web2)
    bad_limits:
      max_connections: 500        # partial override -> the trap
    limits_override:
      max_connections: 500        # kept separate -> the fix

    # TODO 2 — site.yml: merge instead of replace
    msg: "{{ inventory_hostname }}: merged = {{ limits | combine(limits_override | default({})) }}"

    # TODO 3 — site.yml: pin mode with set_fact (level 19)
    - name: Pin mode with set_fact
      ansible.builtin.set_fact:
        mode: set_fact_value

solution/run.sh drives the whole chapter with an ephemeral venv and connection=local
(no managed nodes): the specificity ladder (host beats group, -e beats all), the dict
trap (web2 drops a key), the combine fix (web2 keeps both keys), set_fact stickiness,
and ansible-inventory --host as the tracing tool.

## The three questions

**a. Why the list beats the intuition.**

The three principles are an excellent map of the terrain, but they are a summary, not the
law, and the law is the twenty-two-line list. The intuition "the more specific wins"
holds across most of the middle of the scale — host beats group, play beats inventory —
but it quietly breaks where the list disagrees with our sense of "specific". A task var
feels like the most specific thing there is: it is written on the one task, nowhere else.
Yet set_fact sits at level 19 and task vars at level 17, so a value pinned earlier with
set_fact wins over a task var set right on the failing task, and the task var is ignored
with no error. If you diagnosed that clash by intuition alone you would stare at the task,
see mode: task_var right there, and conclude it must win — and waste an afternoon, because
the thing that beat it is invisible from where you are looking: a set_fact ten tasks
back. That is the whole reason the list exists and the chapter is worth a number: the
principles tell you where to look first, but only the ranked list tells you, without
guessing, which of two real sources wins. When a value surprises you, you stop reasoning
and consult the list (and print the value with debug to confirm).

**b. Why replace is more predictable than merge, and how to merge on purpose.**

Ansible replacing a whole dictionary when a higher level redefines it looks harsh, but it
is the predictable choice, because a value has exactly one owner: whoever defines
bad_limits at the highest level owns all of it, and what you read is exactly what that
level wrote — no invisible contribution leaking in from a lower level you forgot about.
Automatic deep-merge (which does exist, as hash_behaviour=merge) trades that clarity for
danger: the effective dictionary becomes the union of every level that ever touched it,
so the value at run time depends on files you are not looking at, a key can be injected by
some distant group_vars, and removing a key requires finding and editing whichever level
first introduced it. It also changes the behaviour globally, for every dictionary in the
project, to fix one. Predictable-but-blunt beats convenient-but-spooky, so replace is the
default. When you genuinely want to merge, you do it explicitly and locally, three ways in
rough order of preference: (1) keep the override in a separate variable and combine it at
the point of use — limits | combine(limits_override | default({})) — which is visible,
scoped to that expression, and leaves precedence untouched; (2) simply repeat all the keys
in the higher-level definition, honest and obvious for small dicts; (3) as a last resort,
hash_behaviour=merge, project-wide and discouraged. Prefer combine: it says "merge, here,
these two" in one line a reviewer can read.

**c. Why use -e sparingly, and the one design rule that ends the question.**

-e sits at level 22 and beats everything, which is exactly why it is a poor daily habit. A
value passed with -e overrides your group_vars, your host_vars, your play vars, your
set_facts — silently and totally — so a playbook run with a stray -e can behave nothing
like the same playbook run without it, and nothing in the versioned files explains why.
That is perfect for what -e is for: a one-off, deliberate override in an emergency or a
special run, where you *want* to bulldoze the configured value and you know you are doing
it. It is corrosive as routine, because it moves the real configuration off into
shell history and muscle memory, out of review and out of git, and it trains you to reach
for the sledgehammer instead of fixing the value where it belongs. And the single design
rule that dissolves most "why did that value win?" questions is: give every variable one
home. If a name is defined in exactly one place, there is no contest to resolve, no list
to consult, no surprise to debug — precedence only matters when the same name lives in two
places at once, so the cheapest way to master precedence is to arrange never to depend on
it. Distinct names for distinct things, one owner per value, and -e reserved for the rare
deliberate override: do that and the twenty-two levels become trivia you rarely need.
