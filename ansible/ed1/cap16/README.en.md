# Chapter 16 — The section

**Level:** Intermediate

The playbook of chapter 15 can decide and repeat — but it has grown: tasks, variables,
templates, handlers, all piled into a single file. Tomorrow a second project will want the
same app: do you copy and paste? The **role** is the answer. It is a **section** of the
orchestra: a self-contained block, holding its own tasks, its own files, its own default
tuning, that the conductor calls by name — and that you can reuse in any concert. In this
chapter you turn that bloated playbook into a clean role, and the playbook shrinks back to
three lines.

## Objectives

- The **problem**: the playbook that never stops growing (16.1).
- **What a role is**: a folder with a precise structure (16.2, 16.3).
- The playbook that **becomes tiny** (16.4).
- **defaults versus vars**: the heart of reusability (16.5).
- **files and templates**: no more paths (16.6).
- **meta and dependencies** (16.7); **include_role and import_role** (16.8).
- The skeleton with **ansible-galaxy init** (16.9); anatomy of a good role (16.10).

## Prerequisites

- The chapter 6 venv (or start/requirements.txt).
- Docker for one node. Network on first boot.
- Templates, variables and handlers of chapters 12, 14, 15; the precedence of chapter 13.

## The scenario

You take a web app's configuration and package it into the **webapp** role: a folder with
tasks, a template, a static file, a handler, and two kinds of variables. The playbook that
uses it will be three lines long. And you will discover why some of the role's variables let
themselves be changed from outside and others do not.

## Step by step

### Phase 0 — Power the node on

    bash start/nodes.sh up

One container (web1) with the deploy user.

### Phase 1 — The problem, and what a role is

A role is a **folder with a precise structure**: each kind of content has its own
sub-folder, and each has a main.yml that Ansible loads by itself.

    roles/webapp/
    ├── defaults/main.yml      # overridable variables (the knobs)
    ├── vars/main.yml          # internal variables (protected)
    ├── tasks/main.yml         # what the role does
    ├── handlers/main.yml      # its handlers
    ├── templates/app.conf.j2  # its templates
    ├── files/motd             # its static files
    └── meta/main.yml          # metadata and dependencies

You do not have to remember it: **ansible-galaxy init** creates it (16.9):

    ansible-galaxy init roles/webapp

makes defaults/, files/, handlers/, meta/, tasks/, templates/, vars/ (and tests/), each with
its main.yml. You fill in the main.yml files.

### Phase 2 — files and templates: no more paths (TODO 2)

Here is the role's first gift. Complete **TODO 2** in roles/webapp/tasks/main.yml: the task
that renders the config with **src and no path**:

    - name: Render the config
      ansible.builtin.template:
        src: app.conf.j2          # no path: Ansible looks in templates/
        dest: "{{ config_dir }}/app.conf"
      notify: reload webapp

    - name: Deploy the motd
      ansible.builtin.copy:
        src: motd                 # no path: Ansible looks in files/
        dest: "{{ config_dir }}/motd"

Inside a role, template looks for src in templates/ and copy looks in files/,
**automatically**. No absolute paths: move the role wherever you like and the references
still work — that is Question b. And the reload webapp handler you notify lives in
handlers/main.yml: it too is found by itself.

### Phase 3 — defaults versus vars: the heart of reusability (TODO 1)

A reusable role must offer **knobs** — values whoever uses it can change — and protect its
**internal gears** — values not to be touched from outside. Ansible achieves this with two
directories at *opposite precedence* (ch. 13):

- **defaults/** is level **2**, almost the weakest: anything overrides it. Put the knobs
  here.
- **vars/** is level **15**, high: it beats the inventory, group_vars, host_vars, play. Put
  the gears here.

Complete **TODO 1** in roles/webapp/defaults/main.yml with the knobs:

    app_name: myapp
    port: 8080
    features: [logs, cache]

And look at vars/main.yml (already written), the internal gear:

    config_dir: /etc/webapp

Now the proof. The lab's group_vars/web.yml tries to change *both*:

    app_name: webfromgroup     # group_vars (level 6)
    config_dir: /etc/WRONG      # group_vars (level 6)

Run it and read the rendered config:

    app_name = webfromgroup      # group_vars (6) BEAT the default (2): knob turned
    config_dir = /etc/webapp     # the role's vars (15) WON over group_vars (6): gear protected

/etc/WRONG is never even born. This is the golden rule of roles: **the reader's knobs in
defaults, the internal constants in vars** — Question a.

### Phase 4 — The playbook becomes tiny (TODO 3)

All the logic is in the role. Complete **TODO 3**: the playbook that uses it, three lines:

    - name: Configure the web tier
      hosts: web
      become: true
      roles:
        - webapp

Run it: Ansible loads tasks/main.yml, the handlers, the variables, and resolves the paths —
all because the folder is called webapp and has the right structure. The playbook does not
know *how* the web app is configured: it only knows *who* to call. If another project wants
the same app tomorrow, it is three lines again.

### Phase 5 — meta, dependencies, and the two ways to include

- **meta/main.yml** (already written) carries the metadata (author, licence, minimum Ansible
  version) and, under dependencies, the **other roles** this one requires: Ansible runs them
  *first*. It is like saying "the strings section needs the brass tuned already".
- Besides roles:, you can pull a role in *mid-play* two ways (16.8): **import_role** is
  **static** (Ansible expands it when it *reads* the playbook, before starting);
  **include_role** is **dynamic** (it resolves it *during* execution). The difference matters
  when you put it inside a loop or under a when that depends on a runtime variable: there you
  need include_role — Question c.

### Phase 6 — Anatomy of a good role

- **A single responsibility**: a role configures *one* thing (the web app), not "the whole
  server".
- **Documented defaults**: they are the public interface; whoever uses the role reads there
  what can be changed.
- **No absolute paths**: use files/ and templates/.
- **Idempotent**: like every playbook (ch. 10), re-running it must do no harm.
- **A clear name**: a role is invoked by name — let the name say what it does.

## Done when

- ansible-galaxy init creates the skeleton; the main.yml files are filled in.
- Rendered config: **app_name = webfromgroup** (group_vars beats defaults), **config_dir =
  /etc/webapp** (the role's vars beats group_vars; /etc/WRONG does not exist).
- template (app.conf.j2) and file (motd) resolved **with no path**, from the role's folders.
- The **reload webapp** handler fires (from the role's handlers/main.yml).
- The playbook is **three lines** (roles: - webapp); re-running → **changed=0**.

## Questions to reflect on

**a.** app_name is in defaults, config_dir in vars. Why? What do the two opposite precedence
levels (2 versus 15) buy you in terms of reusability — and what would go wrong if you put
config_dir in defaults, or app_name in vars?

**b.** In the role you write src: app.conf.j2 with no path, and Ansible finds it. How, and
why is this auto-resolution what makes a role *portable* (movable and shareable) while an
absolute path would nail it to one machine?

**c.** import_role is static, include_role is dynamic. Describe the difference in the
*moment* the two are resolved, and give a concrete case where you must use include_role
because import_role would not work (think of a loop, or a when on a variable known only at
run time).

## Cleanup

    bash start/nodes.sh down

## Where it leads

You have a clean, reusable role — at home. Chapter 17 opens it to the world: **Ansible Galaxy
and collections** — downloading roles written by others, declaring dependencies in
requirements.yml, and the fully qualified names (FQCN) like ansible.builtin.copy you have
already seen, now explained in full.
