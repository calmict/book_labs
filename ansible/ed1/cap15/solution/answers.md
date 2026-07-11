# Chapter 15 — Answers (model solution)

## The completed TODOs

    # TODO 1 — loop over a list of dicts, with a clean label
    - name: Create the application users (loop over a list of dicts)
      ansible.builtin.user:
        name: "{{ item.name }}"
        shell: "{{ item.shell }}"
        create_home: false
      loop: "{{ app_users }}"
      loop_control:
        label: "{{ item.name }}"

    # TODO 2 — a list under 'when' means AND
    when:
      - app_env == 'prod'
      - enable_metrics | bool

    # TODO 3 — act on a registered result (no braces in when)
    when: not sentinel.stat.exists

solution/run.sh runs the playbook four ways and checks the node: dev (loops act,
three conditionals skip, first-run fires), dev re-run (first-run now skips), prod +
metrics + tuning (the three files appear), prod only (metrics stays off — the AND
needs both). Guaranteed teardown.

## The three questions

**a. Braces in module args, no braces in when.**

The difference is what the two positions expect. A module argument expects a *value*, so
you write "{{ app_env }}" to interpolate the variable's value into a string that is
otherwise literal text — the braces mark "evaluate this bit and paste the result here".
A when expects a *condition*, and Ansible already treats the whole of when as a Jinja2
expression to be evaluated, so you write the bare expression app_env == 'prod': there is
nothing to interpolate into, the entire line *is* the thing being evaluated. Wrapping it
as when: "{{ app_env == 'prod' }}" asks Jinja to first render the expression to a string
and then evaluate that string — a double evaluation that happens to work but is fragile
and noisy, which is why Ansible emits the warning "conditional statements should not
include jinja2 templating". The same no-braces rule holds for every field that is itself
an expression: changed_when, failed_when, until, and assert's that. The single exception
is when a whole value *is* a variable and you are assigning it rather than evaluating a
condition — some_arg: "{{ my_var }}" — where the braces are correct because you are back
to interpolating a value. Rule of thumb: braces when you paste a value in, no braces when
the whole field is already a condition.

**b. A loop over dicts vs two parallel loops.**

Looping over a list of dicts keeps each record's fields *together*, which is both safer
and more expressive than two parallel loops (one over names, one over shells). With two
lists you rely on their order and length matching by hand — websvc must be the first name
and /bin/bash the first shell — and the day someone inserts a user in one list but forgets
the other, the pairs silently shear apart: batchsvc gets bash, a real bug with no error.
A list of dicts binds name and shell in the same item, so item.name and item.shell can
never drift out of sync, and adding a user is one self-contained entry, not a coordinated
edit in two places. It also scales to richer records: add a groups or a comment field and
every user carries it, no third parallel list. The cost is that item is now a structure,
so the default loop output prints the whole dict on every iteration — noisy and, if the
dict ever holds a secret, a leak. That is what loop_control: label is for: it sets what
the run prints per iteration, label: "{{ item.name }}", so you see a tidy list of names
instead of a wall of dictionaries (and loop_control also offers loop_var, to rename item
in nested loops, and index_var). Structure your data by record, then label the loop so the
output stays readable.

**c. Hand-built idempotence (register + when) vs the module's own.**

Reach for register + when only when the action you are guarding is *not itself
idempotent* — when there is no module that already knows how to check "is this already
done?" and skip. Creating a user or a directory is the easy case: the user and file
modules inspect the target and act only if reality differs, so you just declare the
desired state and re-running is free — building your own "does the user exist? then skip"
around them would be redundant and, worse, less correct, because the module checks *the
full state* (name, shell, home) while your hand-rolled guard usually checks only
existence, so a user whose shell drifted would be silently left wrong. The sentinel
pattern earns its place when the action has no notion of "already done" you can express
declaratively: a one-time data migration, a run-once bootstrap, seeding a database,
anything where doing it twice is harmful and no module tracks whether it happened. There
you record the fact yourself — the .provisioned file — and gate the task on it. So the
line is: if a module models the end state, let the module be idempotent and keep your
playbook declarative; only when the operation is inherently one-shot and unmodelled do you
build the check yourself with register + when, and then keep the recorded fact honest so
the guard cannot be fooled.
