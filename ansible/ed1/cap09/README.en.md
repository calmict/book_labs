# Chapter 9 — The cue, not the score

**Level:** Foundational

The address book answers the roll (ch. 8). Now the conductor gives the first orders —
but without writing the full score (that is the playbook, ch. 10). An **ad-hoc**
command is a *cue*: one module, one target, right now, across the whole fleet. Perfect
for a one-off (is it up? how much disk? restart that service); wrong for anything to
repeat or version — that needs the score. Here you learn the anatomy of the cue, the
arsenal of modules, and the crucial difference — which you already sensed in ch. 5 —
between a **switch** module and a **doorbell** command.

## Objectives

- When ad-hoc is **right** and when it is **wrong**.
- The **anatomy**: ansible <pattern> -m <module> -a "<args>" [-b].
- **command vs shell** (pipes and redirections), and why both are "doorbells".
- The **arsenal**: copy and file (idempotent switches), setup (the facts = the
  chapter 2 interview).
- The **forks**: measurable parallelism (ch. 7).
- **-b / become**: administrator on the fly (ch. 7 and 11).
- The **real cases** (9.8): the morning round.

## Prerequisites

- The chapter 6 venv (or rebuild it with start/requirements.txt).
- Docker for two nodes. Network on first boot (apt on the nodes).

## The scenario

Two web servers, **web1** and **web2**. You connect as **deploy** — a *non*-root user
with sudo — so you see become in action: without -b you are deploy, with -b you are
root.

## Step by step

### Phase 0 — Power the nodes on

    bash start/nodes.sh up

Two containers with the deploy user (passwordless sudo), sshd and python3.

### Phase 1 — The anatomy, and the ping

    ansible -i start/inventory.ini web -m ping

The anatomy of the cue: **pattern** (who, from ch. 8) + **-m module** (what) + **-a
args** (how) + **-b** (optional, with root's rank). The default module is command, so
this is already a complete cue:

    ansible -i start/inventory.ini web -a uptime

### Phase 2 — command versus shell

    ansible -i start/inventory.ini web1 -m command -a 'echo ciao | wc -c'
    ansible -i start/inventory.ini web1 -m shell   -a 'echo ciao | wc -c'

The first prints **literally** ciao | wc -c: command uses **no** shell, the pipe is
just text. The second prints **5**: shell hands it all to /bin/sh, the pipe runs.
Rule: **command by default** (safer), **shell only** when you truly need pipes,
redirections or variables. And watch the colour: both always say **CHANGED** — they
are *doorbells* (ch. 5): the exit code cannot tell whether anything really changed.

### Phase 3 — The switch of the arsenal: copy

Complete **TODO 1** in start/runbook.sh: deploy the motd file with **copy** (and -b,
since /etc is root's). Then run the runbook **twice** and watch the copy line:

    web1 | CHANGED => ...      # first run: the file was missing, it wrote it (yellow)
    web1 | SUCCESS => ...      # second run: already in place, "changed": false (green)

**This is a switch** (ch. 5): the module inspects the file's state and acts *only if
needed*. That is the whole difference from command.

### Phase 4 — file + become

Complete **TODO 2**: ensure the directory /etc/cap09.d exists, with **file
state=directory** and -b. Idempotent too (changed → ok), and -b is required because
you write under /etc.

### Phase 5 — The administrator on the fly (-b)

    ansible -i start/inventory.ini web1 -m command -a whoami        # -> deploy
    ansible -i start/inventory.ini web1 -b -m command -a whoami      # -> root

This is the **become** of chapter 7 (there the default in the cfg), here explicit on
the line. The rule: ask for root's rank **only** when you need it.

### Phase 6 — setup: the interview

Complete **TODO 3**: read *one* fact with **setup** and a filter:

    ansible -i start/inventory.ini web1 -m setup -a 'filter=ansible_distribution'

These are the **facts** of chapter 2 (the machine telling its own story), now on
demand. It is the mine chapter 12 will draw variables from.

### Phase 7 — The forks: parallelism

    ansible -i start/inventory.ini web -a 'sleep 3'                # two hosts in parallel: ~4s
    ansible -i start/inventory.ini web --forks 1 -a 'sleep 3'      # in a row: ~6s

Chapter 7's forks made visible with a stopwatch: it is the difference between doing
three thousand servers in a minute or in an hour.

### Phase 8 — The morning round (the real cases)

The completed runbook.sh is ad-hoc at its trade: who is up (ping), for how long
(uptime), the motd refreshed (copy), the directory in place (file), one fact read
(setup). Fast, operator-grade actions — that you would **not** put into production
without a repeatable score.

## Done when

- The completed runbook.sh runs: **motd** deployed (copy), **/etc/cap09.d** created
  (file+become), **one fact** read (setup).
- copy and file: **green on the second run** (idempotent). command: **always
  CHANGED**.
- command vs shell: the pipe is **literal** with command, **executed** with shell.
- -b: whoami goes from **deploy** to **root**.

## Questions to reflect on

**a.** When is an ad-hoc command the right tool, and when do you need a playbook
instead? (Think: one-off vs repeatable, versioned, reviewable.)

**b.** copy reports ok on the second run, command reports changed every time. Tie it to
chapter 5: which of the two is a **switch** and which a **doorbell**, and why should
you use changed_when for command — or, better, reach for a dedicated module?

**c.** Why is command the default and not shell? What do you risk passing untrusted
input to shell that you would not risk with command?

## Cleanup

    bash start/nodes.sh down

## Where it leads

The cue is for things on the fly. But for something to do every day, in order,
versioned and reviewable, you need the **written score**: the playbook, chapter 10 —
where these same modules stop being scattered cues and become a partitura.
