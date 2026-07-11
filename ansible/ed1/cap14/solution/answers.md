# Chapter 14 — Answers (model solution)

## The completed TODOs

    # TODO 1 — notify the topic from both config tasks (site.yml)
    notify: "app config changed"

    # TODO 3 — control the command's changed state, and notify (site.yml)
    register: forced
    changed_when: force_reload | bool
    notify: "app config changed"

    # TODO 2 — two handlers, both subscribing to the topic via listen (site.yml)
    handlers:
      - name: reload app
        listen: "app config changed"
        ansible.builtin.shell: "date -Iseconds >> /var/log/myapp/reloads.log"
      - name: bump reload metric
        listen: "app config changed"
        ansible.builtin.shell: "echo reloaded >> /var/log/myapp/metrics.log"

solution/run.sh drives four runs and counts the reload log: fresh -> 1 (two tasks
notify, each handler fires once via listen), no change -> still 1, config changed -> 2,
force_reload=true -> 3. Guaranteed teardown.

## The three questions

**a. Why handlers run at the end, and only on changed.**

The two rules together are exactly what makes notify/handler a reload-only-when-needed
tool rather than a fancy way to run a task. "Only on changed" is what ties the reaction
to reality: the handler fires because a task actually modified something, so a service
restarts precisely when its configuration changed and stays untouched — no gratuitous
downtime — on every run where nothing did. Strip that rule out and the handler fires every
run, which is just an unconditional task at the bottom of the play: you are back to
restarting the service each time you run the playbook, the very waste the pattern exists to
avoid. "At the end of the play" is what makes the reaction efficient and coherent. Ten
tasks might each touch a piece of the same config; if the handler ran immediately on the
first notification, the service would restart mid-configuration, on a half-applied state,
and then again on the next notification, and the next — many restarts, some against a
broken intermediate config. Deferring to the end means all the changes land first, then the
service reloads once, against the finished state. And it is what allows rule 3
(deduplication): because handlers are collected and run at the end, ten notifications of the
same handler collapse into one run. Immediate execution would make dedup impossible and
"restart once after everything settled" unexpressible. Together the rules encode the real
operational goal: apply everything, then react, once, only if something actually changed.

**b. Why changed_when is essential for a command that notifies, and its opposite.**

A command (or shell) is a doorbell (chapter 9): Ansible runs it and reports that it ran,
with no idea whether it changed anything, so by default it reports changed on every single
run. If that task carries a notify, the handler therefore fires on every run — the config
did not change, nothing needed reloading, but the service restarts anyway, every time,
which is exactly the false alarm handlers are supposed to prevent. changed_when hands you
the judgment the command lacks: changed_when: force_reload | bool makes the task report
changed only when force_reload is true, so it notifies — and reloads — only when you
actually mean to, and stays silent otherwise. Without it, the reload log would grow by a
line on every run regardless of any real change, and you would lose the ability to tell "a
real change happened" from "the playbook ran again". The opposite use is just as important:
changed_when: false tells Ansible a command is read-only — a health check, a "cat this
file", a "get the current version" — so it never reports changed, never colours the run
yellow, and never trips a handler by accident. So changed_when is the two-sided control over
the doorbell: false to silence a command that only reads, an expression to fire it exactly
when a real change occurred. Any time a command feeds a handler, you owe it a changed_when.

**c. The failed-play trap, and how to prevent it.**

Handlers run at the end of the play (rule 1), so there is a dangerous window: a task
notifies the reload, then a later task fails and the play aborts before the end — the
handler never runs. That alone would be recoverable if the next run retried the reload, but
it does not, and that is the trap: on the next run the config task finds the file already in
its desired state (you wrote it last time), reports ok not changed, and therefore does not
notify. The handler has nothing summoning it, so it never fires — and you are left in a
silent, stable-looking bad state: the new configuration is on disk, but the running service
was never reloaded and is still serving the old one, indefinitely, with green playbook runs
that reassure you everything is fine. It is dangerous precisely because nothing looks wrong:
no error, no changed, no hint that a reload is owed. The fix is to not let a notified
handler be lost to a later failure. --force-handlers (or force_handlers: true in the play,
or ANSIBLE_FORCE_HANDLERS) runs any handler that was already notified even if a subsequent
task fails, so the reload happens before the play gives up. And meta: flush_handlers lets
you force the pending handlers to run at a chosen safe point mid-play — for example right
after the config is written and validated, before the riskier tasks — so the reload is
committed while you know the config is good. Design so the reload cannot be silently
stranded: flush at a safe checkpoint, or force handlers on failure.
