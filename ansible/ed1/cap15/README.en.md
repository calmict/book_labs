# Chapter 15 — If, and for each

**Level:** Intermediate

So far every task did one thing, once, always. But reality adapts: dev and prod are not the
same, some features are optional, some actions must be repeated over twenty items. You need
two new powers. **when** gives a task the ability to *decide*: act only *if* a condition is
true. **loop** gives it the ability to *repeat*: one task, many items. With these two — and
the braces trap that comes with them — a playbook stops being a fixed list and becomes an
intelligent procedure.

## Objectives

- The **problem**: a playbook that adapts (15.1).
- **when**: the task that decides whether to act (15.2), and the **braces trap** (15.3).
- **register + when**: conditions on a task's outcome (15.4).
- **Composite conditions**: and, or, the AND list (15.5); and **is defined** (15.6).
- **loop**: one task, many items (15.7), including lists of **dicts** (15.8).
- **loop + register** and **loop_control** (15.9, 15.10); the old **with_*** (15.11).
- The **braces, once and for all** (15.13).

## Prerequisites

- The chapter 6 venv (or start/requirements.txt).
- Docker for one node. Network on first boot.
- The variables and Jinja2 of chapter 12; the changed state of chapter 5.

## The scenario

One node, **web1**, that you provision **adaptively**: it creates the app users and the
feature directories (repetition), but drops the production marker only in prod, enables
metrics only when asked, and applies tuning only if you pass it (decision). One playbook
that behaves differently depending on how you call it.

## Step by step

### Phase 0 — Power the node on

    bash start/nodes.sh up

One container (web1) with the deploy user.

### Phase 1 — The problem

A rigid playbook *always* does the same things. But you want the *same* file to configure
dev and prod, create three directories without writing three tasks, and skip an action
entirely when it is not needed. You need a switch to decide and a multiplier to repeat: when
and loop.

### Phase 2 — when, and the braces trap

**when** adds a condition to a task: the task acts only if it is true, otherwise skipping
appears. Look at the production marker task, already written:

    - name: Drop the production marker (prod only)
      ansible.builtin.copy:
        content: "PROD\n"
        dest: /srv/app/PRODUCTION
      when: app_env == 'prod'

With app_env=dev, the output says skipping: [web1] and the file is not born. With
-e app_env=prod, the task acts.

**The braces trap (15.3):** in a module you write "{{ app_env }}" to *insert* the value; in
when you write app_env == 'prod' **without** braces. Because when is *already* a Jinja2
expression: Ansible evaluates it by itself. If you add braces — when: "{{ app_env == 'prod'
}}" — it works but you earn the warning "conditional statements should not include jinja2
templating". Rule: inside when, bare expressions.

(Note: the variable is called app_env, not environment — the latter is a *reserved* Ansible
name.)

### Phase 3 — loop: one task, many items (TODO 1)

The feature directory is already repeated with **loop** over a simple list:

    - name: Create the feature directories
      ansible.builtin.file:
        path: "/srv/app/{{ item }}"
        state: directory
      loop: "{{ feature_dirs }}"       # [logs, cache, run]

Inside the loop, each element is **item**. Complete **TODO 1**: create the app users with a
loop over a **list of dicts** (15.8), where each item has several fields:

    - name: Create the application users
      ansible.builtin.user:
        name: "{{ item.name }}"
        shell: "{{ item.shell }}"
        create_home: false
      loop: "{{ app_users }}"
      loop_control:
        label: "{{ item.name }}"

item.name and item.shell reach into the dict with a dot. And **loop_control: label** (15.10)
keeps the output clean: instead of printing the whole dict on every pass, it shows only the
name. (loop_control also offers loop_var, to rename item in nested loops, and index_var.)

Two useful notes: registering a loop (15.9) — register on a looped task — gives you a result
whose .results is a **list**, one entry per iteration, to walk through and inspect each pass.
And the old **with_items**, with_dict… (15.11) are the historical form of loop: they still
work, but the modern one is loop — use that.

### Phase 4 — register + when: acting on the outcome (TODO 3)

Sometimes the condition depends on *how the node is right now*. First you query it
(register), then you decide (when). The task that looks for the sentinel is already written:

    - name: Look for the first-run sentinel
      ansible.builtin.stat:
        path: /srv/app/.provisioned
      register: sentinel

Complete **TODO 3**: the first-time task must run *only* if the sentinel is not there yet:

    - name: First-time provisioning
      ansible.builtin.copy:
        content: "first run\n"
        dest: /srv/app/firstrun.txt
      when: not sentinel.stat.exists

On the first run the sentinel is missing → the task runs. Then a last task writes
/srv/app/.provisioned; on the re-run the sentinel is there → the first-time task **skips**.
You have made "by hand" idempotent an action that must happen exactly once — Question c.

### Phase 5 — Composite conditions and is defined (TODO 2)

A condition can combine several tests. The most readable way is a **list under when**, which
means **AND** (all true). Complete **TODO 2**: enable metrics only in prod *and* only when
asked:

    - name: Enable metrics (prod AND enabled)
      ansible.builtin.file:
        path: /srv/app/metrics.enabled
        state: touch
      when:
        - app_env == 'prod'
        - enable_metrics | bool

Both are required: with -e app_env=prod but enable_metrics false, the task skips. You can
also write and/or inline (when: a and b), but the AND list is more readable. And for
variables that *might not exist* (15.6), the test is **is defined**: the tuning task runs
only if you pass it:

    when: tuning_profile is defined

Without -e tuning_profile=..., it skips — without blowing up on "undefined variable".

### Phase 6 — The braces, once and for all

The rule that ends every doubt:

- **With** braces {{ }}: when you *insert* a value — in module arguments, in templates, in
  strings.
- **Without** braces: when you write an *expression* Ansible already evaluates as Jinja —
  **when**, changed_when, failed_when, until, assert.
- The only exception: when a whole value *is* a variable (var: "{{ x }}").

## Done when

- **loop**: the users websvc (/bin/bash) and batchsvc (/usr/sbin/nologin) are created; the
  directories logs, cache, run exist.
- **dev** (default): PRODUCTION, metrics.enabled and tuning.conf do **not** exist (three
  skips); firstrun.txt does.
- **Re-run**: the first-time task **skips** (sentinel).
- **-e app_env=prod -e enable_metrics=true -e tuning_profile=fast**: the three files appear.
- **-e app_env=prod** alone: metrics.enabled does **not** appear (the AND wants both).

## Questions to reflect on

**a.** In a module's arguments you write "{{ app_env }}", but in when you write app_env ==
'prod' without braces. Why the difference, what happens (and what do you see) if you put
braces in when, and what is the only exception to the rule?

**b.** The users loop runs over a *list of dicts* (item.name, item.shell), not a simple
list. Why is that more powerful than two separate loops (one for names, one for shells), and
what is loop_control: label for?

**c.** The sentinel (register + when: not sentinel.stat.exists) makes the first run "by
hand" idempotent. But the user module and the file module are *already* idempotent by
themselves (ch. 5 and 10). When must you build idempotence with register + when, and when is
it better — and safer — to let the module do it?

## Cleanup

    bash start/nodes.sh down

## Where it leads

Your playbook now decides and repeats: it has become long and capable. Chapter 16 gives it a
home: **roles** — the structure that packages tasks, variables, files and handlers into a
reusable component, so the playbook shrinks back to tiny and the logic lives in a tidy place.
