# Chapter 10 — The written score

**Level:** Foundational

In chapter 9 the conductor gave cues on the fly: one module, one target, right now.
Useful, but fleeting — no record, nothing to review, nothing to re-run with confidence.
Now you write the **score**: the **playbook**, a YAML file that puts the same modules in
order, with a name, under version control. This is the heart of Ansible — from here on
almost everything is a playbook. You learn the layered structure (play → task →
module), write your first playbook line by line, learn to read its output, and
rediscover the property that matters most of all: **re-running it does no harm** (the
acid test of ch. 5, now at scale).

## Objectives

- Why the playbook, not the cue: **repeatable, versioned, reviewable**.
- The **layered structure**: play (who + a list of tasks) → task (name + module +
  args) → module.
- The **first playbook line by line**: ---, name, hosts, become, vars, tasks.
- **Running and reading the output**: PLAY, TASK, Gathering Facts, PLAY RECAP and its
  counters.
- The **acid test**: re-run → changed=0 (idempotence).
- **More plays** in one file.
- Directives useful from the start: **vars**, **become_user**, **tags** (--tags /
  --skip-tags).
- **Good habits** from the first line.

## Prerequisites

- The chapter 6 venv (or rebuild it with start/requirements.txt).
- Docker for three nodes. Network on first boot.
- The copy and file modules of chapter 9; the inventory of chapter 8.

## The scenario

Three nodes: **web1** and **web2** (the web group), **db1** (the db group). You connect
as **deploy** (passwordless sudo), so become works as in ch. 9. A single file, site.yml,
configures both tiers — web and database — in two separate plays.

## Step by step

### Phase 0 — Power the nodes on

    bash start/nodes.sh up

Three containers with the deploy user, sshd and python3.

### Phase 1 — From the cue to the score: the anatomy

Chapter 9 ended with a question: what do you do when the action must be **repeated**,
ordered, versioned, reviewed by a colleague? The answer: a written score. Here is its
layered structure:

- a **play** says *to whom* (hosts) and carries a **list of tasks**;
- a **task** has a **name** (readable prose), calls **one module**, and passes it the
  arguments;
- the **module** is the tool of ch. 9 (copy, file, …), this time written, not typed on
  the fly.

Three layers, top to bottom: who → what, in order → with which tool.

### Phase 2 — The first playbook, line by line (TODO 1)

Open start/site.yml. The first play's header is already written:

    ---
    - name: Configure the web tier
      hosts: web
      become: true
      vars:
        app_dir: /etc/cap10.d
      tasks:

--- opens the document (ch. 4). The play is **a list item** (the - before name): a
name, a target (hosts: web), root's rank for the whole play (become: true), a play
variable (vars: app_dir), and then tasks:.

Complete **TODO 1**: the first task, which deploys the motd with **copy** — the same
module as ch. 9, now as a task:

    - name: Deploy the message of the day
      ansible.builtin.copy:
        src: motd
        dest: /etc/motd
        mode: "0644"
      tags: [content]

Note three things: the **name** in plain words; the module written with its full name
**ansible.builtin.copy** (a good habit, ch. 17); the **quoted mode** "0644" (ch. 4: 0644
unquoted becomes an octal integer).

### Phase 3 — A variable and a task as root (TODO 2)

Complete **TODO 2**: the task that ensures the app directory, using the play variable:

    - name: Ensure the app directory exists
      ansible.builtin.file:
        path: "{{ app_dir }}"
        state: directory
        mode: "0755"
      tags: [structure]

The double braces {{ app_dir }} are Jinja2 (the engine of ch. 12): "put the variable's
value here". The next task is already written and shows **become_user**: the play rises
to root, but a single task can spell out *which* user to become:

    - name: Drop a marker owned by root
      ansible.builtin.copy:
        content: "web tier configured by Calm ICT\n"
        dest: "{{ app_dir }}/marker"
        mode: "0644"
      become_user: root

### Phase 4 — Run it, and read the output

The cue was launched with ansible; the score with **ansible-playbook**:

    ansible-playbook -i start/inventory.ini start/site.yml

Read the output top to bottom:

    PLAY [Configure the web tier] **************
    TASK [Gathering Facts] ********************      # the ch. 2 interview, automatic
    ok: [web1]
    TASK [Deploy the message of the day] ******
    changed: [web1]
    ...
    PLAY RECAP ********************************
    web1 : ok=4  changed=3  unreachable=0  failed=0  ...

Each **PLAY** is a header, each **TASK** a line per node, in the colours of ch. 5 (ok
green, changed yellow). The **Gathering Facts** is the ch. 2 interview Ansible runs by
itself at the start of the play. The final **RECAP** is the tally per node: how many ok,
how many changed, how many unreachable, how many failed.

### Phase 5 — The acid test: re-run

Run the **same** command again. Look at the recap:

    web1 : ok=4  changed=0  unreachable=0  failed=0

**changed=0.** Nothing changed because nothing *needed* to: copy and file are switches
(ch. 5), they inspect the state and stay put when it is already right. This is the
property that makes a playbook trustworthy: you can re-run it a hundred times and it
always converges to the same state. (Had you used command instead of copy here — a
doorbell from ch. 9 — you would see changed on every run, and lose the acid test: that
is Question a.)

### Phase 6 — More plays in one file (TODO 3)

One file can hold **more than one play**. Complete **TODO 3**: a second play that
configures the database, same shape as the first but targeting db:

    - name: Configure the database tier
      hosts: db
      become: true
      tasks:
        - name: Ensure the data directory exists
          ansible.builtin.file:
            path: /etc/cap10-db.d
            state: directory
            mode: "0755"
          tags: [structure]

Re-run: now you see **two** PLAY headers, and db1 appears in the recap too. One file, one
command, two tiers of the infrastructure configured in order.

### Phase 7 — Tags: run only a part

**Tags** label tasks so you can run a subset. Try:

    ansible-playbook -i start/inventory.ini start/site.yml --tags structure
    ansible-playbook -i start/inventory.ini start/site.yml --skip-tags content
    ansible-playbook -i start/inventory.ini start/site.yml --list-tags

--tags structure runs **only** the tasks tagged structure (the directories); --skip-tags
content skips the copies; --list-tags lists them without running. Handy when the score
is long and you want to re-run one movement only. (Gathering Facts is not your task: it
runs regardless.)

### Phase 8 — Good habits from the first line

- **name on every task**: the output becomes readable and you can resume from a precise
  point (--start-at-task) — that is Question b.
- **one module per task**: a task does one thing.
- **the module's full name** (ansible.builtin.copy): no ambiguity (ch. 17).
- **quote the ambiguous values** of ch. 4 ("0644", "yes").
- before running, **--syntax-check**: it reads the score without touching the nodes.

## Done when

- ansible-playbook site.yml shows **two plays** and a recap with web1/web2 (**ok=4
  changed=3**) and db1 (**ok=2 changed=1**).
- **Re-running → changed=0** on all three (idempotence).
- **--tags structure** runs only the directory tasks; **--skip-tags content** skips the
  copies.
- **--syntax-check** passes.

## Questions to reflect on

**a.** Re-running the playbook gives changed=0: why is this the property that matters
most of all? And if the first task used command "echo ... > /etc/motd" instead of copy,
what would you see on the second run — and what would you have lost? (Tie it to ch. 9's
doorbell.)

**b.** Every task has a readable name. Is it just cosmetics for the output, or does it
buy something concrete once the playbook grows, fails halfway, or ends up in an audit
log? (Think about --start-at-task and whoever reads the result six months from now.)

**c.** become: true sits on the play, but become_user: root sits on a single task. Who
becomes whom, and why is it better to **declare** the privilege in the score than to
pass it by hand on every command as in ch. 9? (A preview of ch. 11.)

## Cleanup

    bash start/nodes.sh down

## Where it leads

You wrote the score and re-ran it without fear. So far, though, privilege was a switch
flipped in bulk (become: true). Chapter 11 opens that box: **become in depth** —
sudoers, the -K password, becoming users other than root, and the methods beyond sudo.
The first real step into the Intermediate tier.
