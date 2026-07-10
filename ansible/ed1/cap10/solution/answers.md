# Chapter 10 — Answers (model solution)

## The completed playbook (the TODOs)

    # TODO 1 — the copy task inside the web play
    - name: Deploy the message of the day
      ansible.builtin.copy:
        src: motd
        dest: /etc/motd
        mode: "0644"
      tags: [content]

    # TODO 2 — the file task, using the play variable {{ app_dir }}
    - name: Ensure the app directory exists
      ansible.builtin.file:
        path: "{{ app_dir }}"
        state: directory
        mode: "0755"
      tags: [structure]

    # TODO 3 — the second play, the database tier
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

solution/run.sh drives the whole chapter with an ephemeral venv and three nodes, and
guaranteed teardown: syntax-check, the first run and its recap, the acid test (re-run
-> changed=0), and the tags.

## The three questions

**a. Why changed=0 on the re-run is the property that matters most.**

Because it is what makes a playbook safe to run at all. An automation you can only run
once is barely automation — it is a one-shot script you must reason about carefully
before every use. A playbook that converges lets you run it a hundred times, on a
whim, in a cron job, in CI, after a half-failed run, and trust that it drives the
fleet to the declared state and then stops touching it. changed=0 is the machine
telling you "reality already matches the score, I did nothing" — which is exactly the
signal you want in steady state, and it makes the *changed* lines meaningful: when
something does report changed on a run that should be quiet, that is real drift worth
looking at, not noise. If the first task used command "echo ... > /etc/motd" instead
of copy, the second run would show changed again — every run, forever — because
command is a doorbell (chapter 9): it executes and reports that it executed, blind to
whether anything changed. You would lose the acid test itself: the recap could no
longer distinguish "nothing needed doing" from "something changed", so drift would
hide in a sea of permanent yellow. The whole value of the written score rests on the
modules under it being switches, not doorbells.

**b. name on every task: cosmetics or something concrete?**

It buys real, compounding value the moment the playbook stops being three lines. The
first payoff is the output: TASK [Deploy the message of the day] tells you at a glance
what is running and, when a task reports changed or failed, *which* one — without a
name Ansible prints the module and a guessy summary, and in a fifty-task role that is
nearly useless. The second is operational: ansible-playbook --start-at-task "Deploy
the message of the day" lets you resume a long play from a known point after fixing a
failure, and that only works because tasks have stable, human names to point at. The
third is everything downstream that reads the run rather than watches it: a CI log, an
AWX/Tower job history, an audit trail six months later — the names are the story of
what the automation did, in language a reviewer (maybe not you) can follow. And a good
name is a tiny design check: if you cannot say in a short phrase what a task does, the
task is probably doing too much (see: one module per task). So the name is
documentation, a debugging handle, and a resume point at once — cosmetics only until
the first time something goes wrong or someone else has to read it.

**c. become on the play, become_user on a task.**

become: true on the play switches privilege escalation on for every task in that play;
by default the target user is root, so each task runs as root on the managed node.
become_user on a single task narrows *who* you become for that task only — here it is
still root, shown explicitly, but it could be become_user: postgres to run one task as
the database user while the rest of the play stays root. So the play sets the general
policy ("this play needs elevation") and the task can refine the identity ("this
particular step runs as that account"). The reason to *declare* the privilege in the
score rather than pass it by hand on every command, as chapter 9's ad-hoc -b did, is
the same reason the whole file exists: the declaration is versioned, reviewable, and
applied uniformly. When "become to root" lives in the playbook, a reviewer can see
exactly which plays and tasks elevate, the policy cannot be forgotten or fat-fingered
on one host out of fifty, and changing it is a diff, not a habit you hope everyone
remembers. Escalation is a security decision; security decisions belong written down,
where they can be read and audited, not retyped. Chapter 11 opens this box in full:
sudoers, the -K password, becoming users other than root, and the methods beyond sudo.
