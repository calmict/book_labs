# Chapter 14 — The recall at the end of rehearsal

**Level:** Intermediate

You change a service's configuration: now it must be **reloaded** to read it. But reloading
it on *every* run of the playbook — even when you touched nothing — is waste and risk:
needless interruptions, dropped connections, for nothing. You want to reload it **only if
the config really changed**. Ansible solves this with the **notify / handler** pair: a task
leaves a *recall*, and at the end of the rehearsal — only if that task reported changed —
the handler fires. It is the changed colour of chapter 5 that stops being a mere signal and
becomes a **trigger**.

## Objectives

- The **problem**: reload only when needed (14.1).
- The **engine**: the changed state (14.2).
- **notify and handlers**: the pair that solves it (14.3).
- The **three golden rules** of handlers (14.4).
- Several handlers together, and the **listen** trick (14.5).
- Controlling the changed state by hand with **changed_when** (14.6).
- A **real example**, from start to finish (14.7).
- **Good habits** with handlers (14.8).

## Prerequisites

- The chapter 6 venv (or start/requirements.txt).
- Docker for two nodes. Network on first boot.
- The changed state of chapter 5; the playbook of chapter 10; the command "doorbell" of
  chapter 9.

## The scenario

Two nodes in the **web** group with a small app configured under /etc/myapp. Whenever a
config file changes, the app must be "reloaded" — and we will show it in a **countable**
way: the handler appends a line to /var/log/myapp/reloads.log. By counting the lines after
each run, you see *exactly* how many times the service was reloaded — and discover it grows
only when it must.

## Step by step

### Phase 0 — Power the nodes on

    bash start/nodes.sh up

Two containers (web1, web2) with the deploy user.

### Phase 1 — The problem, and the engine

An idempotent playbook (ch. 10) does the right thing: if the config is already in place, it
does not rewrite it. But the config and the *running process* are two different things:
changing /etc/myapp/app.conf does not reload the app by itself. You could add a "reload the
app" task at the bottom — but that would run **every time**, even when the config did not
change, restarting the service for nothing. You need a trigger tied to **changed**: the
chapter 5 signal that says "this task *actually* modified something". Reload **if and only
if** changed.

### Phase 2 — notify and handlers (TODO 1)

The mechanism is two pieces. A normal task adds **notify** with the name of a recall; and in
the play's **handlers** section you define that recall — a task like any other, but one that
runs only when called. Open start/site.yml and complete **TODO 1**: add notify to the tasks
that write the config:

    - name: Deploy app.conf
      ansible.builtin.copy:
        content: "greeting = {{ greeting }}\n"
        dest: /etc/myapp/app.conf
      notify: "app config changed"

The handler itself comes in Phase 4. The idea: the task copies the file; **if** the file
changes (changed), it leaves the recall "app config changed"; at the end of the play the
recall is collected and run.

### Phase 3 — The three golden rules

Handlers follow three rules that explain all of their behaviour:

1. **They run at the end of the play**, after *all* tasks — not the moment you notify them.
   First all the work, then the reaction.
2. **They run only if notified by a changed task.** No changed, no recall, no reaction.
3. **They run at most once per play**, no matter how many times they are notified. Two tasks
   notifying the same handler → the handler fires **once** only (dedup).

You will see rule 3 by counting: two tasks notify the same recall, but reloads.log gains
**one** line, not two.

### Phase 4 — Several handlers, and the listen trick (TODO 2)

Often one change must fire *several* reactions: reload the service *and* update a metric.
Instead of notifying two names, you notify a **topic** and several handlers subscribe to it
with **listen**. Complete **TODO 2**: two handlers listening to the same topic:

    handlers:
      - name: reload app
        listen: "app config changed"
        ansible.builtin.shell: "date -Iseconds >> /var/log/myapp/reloads.log"

      - name: bump reload metric
        listen: "app config changed"
        ansible.builtin.shell: "echo reloaded >> /var/log/myapp/metrics.log"

Now notify: "app config changed" fires **both**. listen decouples the *name of the recall*
from the *names of the handlers*: the tasks notify an intention ("the config changed"), not
a list of actions — and tomorrow you add a third handler without touching a single task.

### Phase 5 — Controlling changed by hand (TODO 3)

A command is a **doorbell** (ch. 9): it reports changed on *every* run, because it does not
know what it did. If a command notifies a handler, the handler would fire every time — a
false alarm. **changed_when** gives you back control. Complete **TODO 3** on the task that
forces the reload:

    - name: Force a reload on demand
      ansible.builtin.command: "echo force={{ force_reload }}"
      register: forced
      changed_when: force_reload | bool
      notify: "app config changed"

With changed_when: force_reload | bool, the task is "changed" *only* when you decide. Try it
on a system whose config is unchanged:

    ansible-playbook -i start/inventory.ini start/site.yml -e force_reload=true

The handlers fire anyway — not because a file changed, but because changed_when said
"changed". It is the flip side of ch. 9: there changed_when was for *silencing* a read-only
command (changed_when: false), here it is for *triggering* on purpose.

### Phase 6 — The real example, counted line by line

Put it all in a row and watch reloads.log grow only when it must:

    # 1. first run: the config is born -> handler fires
    ansible-playbook ... start/site.yml                         # reloads.log: 1 line
    # 2. re-run, nothing changes -> handler does NOT fire (rule 2)
    ansible-playbook ... start/site.yml                         # reloads.log: still 1
    # 3. change the config -> handler fires
    ansible-playbook ... start/site.yml -e greeting=ciao        # reloads.log: 2 lines
    # 4. config unchanged but forced -> changed_when triggers
    ansible-playbook ... start/site.yml -e greeting=ciao -e force_reload=true   # 3 lines

Four runs, three reloads: exactly the ones that were needed. No idle restarts.

### Phase 7 — Good habits (and a serious pitfall)

- **Clear names and topics**: notify an intention ("app config changed"), not a command.
- **Idempotent handlers** too: a reload is fine, a "delete and recreate" is not.
- **The failed-play pitfall**: if a task notifies a handler and then the play **fails before
  the end**, the handler does *not* run (rule 1: it fires at the end of the play). On the
  next run the task finds the config already in place → changed=no → it no longer notifies →
  **the handler never fires**: new config, service never reloaded. That is Question c. The
  cure: **--force-handlers** (runs notified handlers even if a later task fails) or
  **meta: flush_handlers** to flush them at a safe point.

## Done when

- First run: reloads.log and metrics.log have **1 line** each (two tasks notify, two
  handlers via listen, each fires **once**).
- Re-running with no changes: the logs **stay at 1** (rule 2).
- With **-e greeting=ciao**: the config changes → the logs go to **2**.
- With **-e force_reload=true**: even with no file changes, changed_when triggers → the logs
  grow again.

## Questions to reflect on

**a.** Handlers run at the *end* of the play and *only* on changed. Why are these two rules
together what makes the pattern useful? What would go wrong if a handler fired *immediately*
on every notification, and what if it fired *always*, changed or not?

**b.** A command reports changed on every run (doorbell, ch. 9). Why, if that command
notifies a handler, does changed_when become essential — and what would you see *without*
it? Describe the opposite use, changed_when: false, and when it is needed.

**c.** A task notifies the reload, then a later task **fails** and the play stops. The
handler did not run. You re-run: the config task now changes nothing (it is already in
place), so it does not notify, and the handler is left grounded — with the new config and the
service never reloaded. Why does this happen, and why is it dangerous? How do you prevent
it?

## Cleanup

    bash start/nodes.sh down

## Where it leads

You made your tasks react to change. Chapter 15 gives them another form of intelligence: to
**decide** and to **repeat** — conditional logic (when, without the braces) and loops
(loop). There a single task will act on twenty files, or skip entirely if a condition is not
met.
