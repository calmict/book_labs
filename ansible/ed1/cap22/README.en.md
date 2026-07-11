# Chapter 22 — When a string snaps

**Level:** Advanced

You can discover the fleet (ch. 21) and act on it. But a real orchestra plays in an imperfect
world: a string snaps mid-concert, a stand falls, a player misses the cue. The question is not
*whether* something will go wrong on one of the thousand nodes at the roll-call, but *what the
conductor does when it happens*. By default Ansible, faced with an error, stops on that host —
prudent, but not enough. This chapter gives you the tools of resilience: recover with
block/rescue/always, retry what is slow, redefine what counts as an error, and — when needed —
stop everything fast before the disaster spreads.

## Objectives

- The default behaviour: **stop on that host** (22.1).
- **block, rescue, always**: Ansible's try/catch/finally (22.2).
- **ignore_errors**: carry on anyway, with judgement (22.3).
- **failed_when and changed_when**: redefine success and change (22.4).
- Retry what is slow: **until, retries, delay** (22.5).
- Fail fast: **any_errors_fatal and max_fail_percentage** (22.6).
- Validate before acting: **assert and fail** (22.7).
- Handlers and failures: **force_handlers** (22.8).
- The **good habits** with error handling (22.9).

## Prerequisites

- The chapter 6 venv (or start/requirements.txt).
- The handlers of chapter 14 (they return here, and learn to survive failures).
- (No nodes: like chapter 13, everything resolves on the control node — several local hosts,
  connection: local — so you see per-host isolation without containers.)

## The scenario

An inventory of four local hosts (web1, web2, web3, db1). A deploy that *must* be resilient: it
validates the preconditions before touching anything, tries the risky step with a safety net,
waits patiently for a slow service, and ignores what is not critical. On one host (db1) the
deploy fails on purpose: you watch how the play does *not* collapse, but recovers.

Prepare the environment:

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    cd start

### Phase 1 — The default: stop on that host (22.1)

With no nets, if a task fails on a host, Ansible *stops with that host* and carries on with the
others. Per-host isolation: db1 can fall while web1/web2/web3 continue. It is prudent but blind
— the fallen host is left halfway, and you have not decided *what* to do about its failure. The
rest of the chapter is: making that decision.

### Phase 2 — Validate before acting: assert (22.7 — TODO 3)

The first resilience is not to start if the premises are wrong. Complete **TODO 3** in site.yml:
an assert that checks deploy_env *before* any action —

    - name: deploy_env must be one we know
      ansible.builtin.assert:
        that: deploy_env in ['dev', 'staging', 'prod']
        fail_msg: "invalid deploy_env '{{ deploy_env }}'"

With a good value, it proceeds. With -e deploy_env=banana, it *fails at once* and writes not a
single file: better to stop at the gate than halfway through the deploy. (assert for a
condition; fail to abort with a message when the logic decides.) Question a.

### Phase 3 — block, rescue, always (22.2 — TODO 1)

The heart: Ansible's try/catch/finally. Complete **TODO 1**: wrap the deploy in
block/rescue/always —

    - name: Deploy with rollback safety
      block:
        - name: Deploy the app
          ansible.builtin.copy: { content: "deployed {{ deploy_env }}\n", dest: "{{ lab }}/{{ inventory_hostname }}.deployed", mode: "0644" }
        - name: Simulate a mid-deploy failure on one host
          ansible.builtin.command: /bin/false
          when: inventory_hostname == fail_host
          changed_when: false
      rescue:
        - name: Roll back
          ansible.builtin.copy: { content: "rolled back\n", dest: "{{ lab }}/{{ inventory_hostname }}.rollback", mode: "0644" }
      always:
        - name: Clean up (always runs)
          ansible.builtin.copy: { content: "cleaned up\n", dest: "{{ lab }}/{{ inventory_hostname }}.cleanup", mode: "0644" }

- **block**: the group of "normal" tasks (the try).
- **rescue**: runs *only if* something in the block failed (the catch) — here the rollback. And
  the error is *handled*: the host is not marked failed, the play continues.
- **always**: runs *regardless*, success or failure (the finally) — the cleanup you cannot skip.

On db1 the deploy fails → rescue (rollback) + always (cleanup) fire. On web* the deploy succeeds
→ no rescue, but always cleans up all the same. Question b.

### Phase 4 — Retry what is slow: until, retries, delay (22.5 — TODO 2)

A service that takes ten seconds to come up is not *broken*: it is slow. Failing on the first try
would be wrong. Complete **TODO 2**: a health check that retries until it passes —

    - name: Health check (slow - retry until healthy)
      ansible.builtin.shell: 'f="{{ lab }}/{{ inventory_hostname }}.hc"; echo x >> "$f"; test "$(wc -l < "$f")" -ge 3'
      register: hc
      until: hc.rc == 0
      retries: 5
      delay: 0
      changed_when: false

**until** is the condition to reach; **retries** how many times to try; **delay** the wait
between attempts. The check here passes only on the third go: Ansible retries (FAILED -
RETRYING...) and moves on when it is healthy, instead of giving up at once.

### Phase 5 — Redefine success, and ignore (22.3, 22.4)

Two tools given in the play, which turn the notion of error on its head:

- **failed_when**: *you* decide what is a failure. A grep that finds nothing exits with rc=1, but
  "not found" is often the right answer, not an error: failed_when: false treats it as success.
  (Its twin changed_when from ch. 5/9 does the same with the yellow colour.)
- **ignore_errors**: a *non-critical* step (sending a metric) can fail without sinking the
  deploy. ignore_errors: true carries on. But with judgement: ignoring a critical error is like
  removing the oil light — the problem stays, you just stop seeing it. Question c.

### Phase 6 — Handlers and failures: force_handlers (22.8)

Remember handlers (ch. 14): they run at the end of the play, only if notified. But if a task
*after* the notify fails, the play stops *before* firing them — and the reload you had already
earned is lost. **force_handlers: true** runs them anyway. handlers.yml shows it:

    ansible-playbook -i inventory.ini handlers.yml       # it fails on purpose...
    cat "$CAP22_LAB/fh.done"                              # ...but the handler ran all the same

### Phase 7 — Fail fast to protect the fleet (22.6)

Sometimes you do *not* want the other hosts to proceed. If the rollout is poisoned, every extra
host that receives it is one more casualty. failfast.yml shows it with **any_errors_fatal:
true**:

    ansible-playbook -i inventory.ini failfast.yml

db1 fails the precheck → "NO MORE HOSTS LEFT": the dangerous action reaches *nobody*, not even
the healthy web hosts. Its graduated sibling is **max_fail_percentage**: "abort if more than 20%
fail" — you tolerate some losses, you stop before the bleeding. The default (stop only on that
host) for independence; any_errors_fatal for all-or-nothing operations.

### Phase 8 — The good habits (22.9)

- **Do not ignore out of laziness.** ignore_errors and failed_when: false are scalpels, not rugs
  to sweep things under: use them where the "failure" truly does not count, never to silence a
  real error.
- **A rescue that really cleans up.** A rescue that writes "rolled back" but does not restore is
  theatre: make always and rescue bring the system back to a known state.
- **Validate at the gate** (assert/fail): a thousand checks downstream cost less than one deploy
  gone wrong halfway.
- **Fail-fast for all-or-nothing, per-host for the independent**: choose based on *how much a
  host depends on the others*.

## Done when

- assert (TODO 3) blocks deploy_env=banana *before* writing any file; with a valid value it
  proceeds.
- block/rescue/always (TODO 1): on db1 the rollback and cleanup markers exist; on web1 the
  deployed and cleanup markers exist but *not* rollback; the play is not failed (rescued=1 on
  db1).
- until (TODO 2): the health check passes after a few attempts instead of failing at once.
- ignore_errors leaves the play at failed=0 (ignored >= 1); failed_when: false treats rc=1 as
  success.
- handlers.yml: fh.done exists despite the failure (force_handlers).
- failfast.yml: with any_errors_fatal the rollout reaches no host.

(Note: this chapter is *not* about idempotence — the deploy fails and recovers on purpose every
run; the point is how it reacts, not that it converges to changed=0.)

## Questions to reflect on

**a.** assert and fail stop the play *before* acting. Why is "validating at the gate" cheaper
than handling the error downstream, and what is the difference of intent between assert (a
precondition that *must* hold) and a plain when that just skips the task if the condition is
false?

**b.** In block/rescue/always, rescue turns a *failed* host into a *handled* one (the play
continues, the host is not marked failed). How is that different from ignore_errors, which also
"carries on despite the error"? When should a failure be *recovered* (rescue) and when *ignored*
(ignore_errors), and why is confusing the two dangerous?

**c.** The default isolates failures per host (one falls, the others continue); any_errors_fatal
does the opposite (one falls, all stop). Neither is "right" in the absolute: what does the choice
depend on? Give an example where per-host independence is what you want, and one where it is
exactly what ruins you.

## Cleanup

Nothing to tear down: no nodes, no containers. The markers land in /tmp/cap22-lab (or wherever
CAP22_LAB points); delete them if you like.

## Where it leads

You can make a playbook survive the unexpected. But the best way to handle an error is *not to
make it*: **chapter 23** opens linting and check mode — ansible-lint that corrects you before you
run, and the "dry run" mode that shows you what would change without touching anything. From the
tools that react to errors, to the ones that prevent them.
