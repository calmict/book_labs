# Chapter 12 — Annotations on the score

**Level:** Intermediate

The score of chapter 10 was rigid: /etc/motd, port 80, those values written inside the
playbook. But web1 and web2 are not identical — different ports, different limits — and
rewriting the playbook for each would be chapter 1's crack returning. **Variables** are
the pencil annotations on the score: a value with a **name**, written once and reused
everywhere, that can arrive from many sources — the group, the single host, the command
line, the facts Ansible discovers on its own. In this chapter you see what shape they
take (the types), how to use them (Jinja2's double braces), **where they live**, how to
capture a result on the fly, and how to keep them tidy.

## Objectives

- **Why** variables: one playbook, many nodes (12.1).
- The **types** of value: string, integer, boolean, list, dictionary (12.2).
- Jinja2's **double braces**: using them, reaching into lists and dictionaries (12.3).
- **Where they live**: play, inventory (group_vars/host_vars), command line -e (12.4).
- The **facts**: the variables Ansible discovers on its own (12.5).
- **Capturing results**: register and set_fact (12.6).
- The **safety nets**: default values (12.7).
- **Keeping order**: where it pays to define what (12.8).

## Prerequisites

- The chapter 6 venv (or start/requirements.txt).
- Docker for two nodes. Network on first boot.
- The playbook of chapter 10; the group_vars of chapter 8; the YAML of chapter 4.

## The scenario

Two nodes in the **web** group. A single template, config.j2, is rendered into
/etc/myapp/config.ini on each — but the file is **not** identical: web1 runs on port
8080, web2 on 8081, and each node states its own hostname and its own worker count. One
score, two different performances, all driven by variables.

## Step by step

### Phase 0 — Power the nodes on

    bash start/nodes.sh up

Two containers (web1, web2) with the deploy user.

### Phase 1 — Why, and what shape they take

Without variables you would write one playbook for web1 and one for web2: two nearly
identical files that drift apart over time (chapter 1's crack). With variables you write
**one** playbook and change only the values. And the values have a **shape** — the types
of chapter 4, now at work:

- **string**: app_name: orchestra
- **integer**: port: 8080
- **boolean**: debug_mode: false
- **list**: features: [metrics, tracing, healthcheck]
- **dictionary**: limits: { max_connections: 200, timeout_seconds: 30 }

(Remember chapter 4: false is a boolean, not the string "false"; rendered into a file it
becomes Python's False. If you need the lowercase string, Jinja2 has | lower.)

### Phase 2 — Jinja2's double braces (TODO 2)

A variable is *used* inside **{{ }}**: Ansible substitutes the name with the value. Open
start/config.j2 and complete **TODO 2** — the lines that draw from the variables,
including reaching into a **list** and a **dictionary**:

    # {{ app_name }} config, rendered on {{ ansible_hostname }}
    port = {{ port }}
    features = {{ features | join(', ') }}
    max_connections = {{ limits.max_connections }}
    log_level = {{ log_level | default('info') }}

Note three Jinja2 gestures: **{{ features | join(', ') }}** turns the list into one line
(the | is a *filter*, chapter 20 is full of them); **{{ limits.max_connections }}** reaches
into the dictionary with a dot; **{{ ansible_hostname }}** you did not define — it is a
**fact** (Phase 4).

### Phase 3 — Where the variables live (TODO 1)

The same variable can sit in different places. Complete **TODO 1** in
start/group_vars/web.yml, adding the features list and the limits dictionary. Then look at
the four sources in play:

- **group_vars/web.yml**: apply to the *whole* web group (app_name, port, features,
  limits).
- **host_vars/web2.yml**: apply to *that one* host — here port: 8081, which **beats** the
  group_vars for web2.
- **the play's vars:** (config_dir: /etc/myapp): local to this play.
- **the command line -e**: the strongest of all. Try:

      ansible-playbook -i start/inventory.ini start/site.yml -e app_name=canary

  In the rendered file app_name is canary on *both* nodes: the extra var beat group_vars.
  (Why -e wins over group_vars follows a precise rule — the 22 of chapter 13. Here it is
  enough to know the command line commands.)

### Phase 4 — The facts: variables Ansible discovers on its own

{{ ansible_hostname }} works without your having defined it: it is a **fact**, gathered by
Gathering Facts at the start of the play (the chapter 2 interview). Ansible discovers
hundreds — ansible_hostname, ansible_distribution, ansible_default_ipv4.address,
ansible_processor_vcpus… — and puts them under ansible_facts. They are the mine from
which the config adapts *to the machine* without your writing a value by hand.

### Phase 5 — Capturing results: register and set_fact (TODO 3)

Sometimes you do not know the value in advance: you discover it by running something on the
node. Two tools:

- **register** captures a task's outcome into a variable:

      - name: How many CPUs does this node have?
        ansible.builtin.command: nproc
        register: nproc_result
        changed_when: false

  Now nproc_result.stdout holds the CPU count.

- **set_fact** creates a *new*, computed variable. Complete **TODO 3**:

      - name: Derive the worker count (2 per CPU)
        ansible.builtin.set_fact:
          worker_count: "{{ nproc_result.stdout | int * 2 }}"

The | int converts the string to a number, then * 2. In the config you will see workers = 8
(on a 4-CPU machine) — a value that **adapts to the node**, not carved in by hand.

### Phase 6 — Safety nets: the defaults

The template has {{ log_level | default('info') }}, but log_level is defined nowhere.
Without the **default** filter, Ansible would fail with "'log_level' is undefined". With
| default('info'), the missing variable slides onto a sensible value. It is the safety net
for optional variables: the playbook does not break if someone forgets to set one.

### Phase 7 — Keeping order: where it pays to define what

The freedom to put a variable anywhere becomes chaos without a rule. The convention:

- true of a **whole group** → group_vars/<group>.yml
- true of a **single host** → host_vars/<host>.yml
- needed **only in this play** → vars: in the play
- a **one-off runtime override** → -e on the command line

Golden rule: in the inventory *who you are and where you live*, in group_vars/host_vars
*what you are made of*. The fewer different places you touch for the same value, the fewer
surprises — and the surprises, when the same name is defined in two places that clash, are
the subject of chapter 13.

## Done when

- The rendered config.ini holds all the types: string (app_name), integer (port), boolean
  (debug), list (features), dictionary (max_connections/timeout).
- **web1 port=8080** (group_vars), **web2 port=8081** (host_vars wins).
- **-e app_name=canary** → canary on both (extra var wins).
- workers comes from **set_fact** (nproc x 2); log_level comes from the **default** (info).
- Re-running → **changed=0** (idempotence).

## Questions to reflect on

**a.** debug_mode: false is a boolean and in the rendered file it becomes False (Python's).
Tie it to chapter 4: why are false/no/yes traps, and when would you quote a value to keep
it a string? What would {{ debug_mode | lower }} change?

**b.** register and set_fact both capture values "at run time". What is the difference
between the two, and why is computing worker_count from nproc with set_fact better than
writing workers = 8 by hand in group_vars? (Think of a node with 8 CPUs instead of 4.)

**c.** app_name is in group_vars, but -e app_name=canary beat it. Where should you define a
"stable group variable" and where a "one-evening override"? And when the same name is set
in *two* places that do not agree, who decides which wins — and why does it take a whole
chapter (13) to answer?

## Cleanup

    bash start/nodes.sh down

## Where it leads

You saw a variable live in four places, and the command line beat the group_vars. That was
not chance: Ansible has a hierarchy of **22 precedence levels**, from the weakest (role
defaults) to the strongest (-e). Chapter 13 lines them all up and teaches you not to be
surprised by the value that "mysteriously" wins.
