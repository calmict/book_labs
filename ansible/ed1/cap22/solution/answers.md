# Chapter 22 - Answers (model solution)

## The completed TODOs

    # TODO 3 (22.7) - site.yml: validate before acting
    - name: deploy_env must be one we know
      ansible.builtin.assert:
        that: deploy_env in ['dev', 'staging', 'prod']
        fail_msg: "invalid deploy_env '{{ deploy_env }}'"

    # TODO 1 (22.2) - site.yml: the deploy with a safety net
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

    # TODO 2 (22.5) - site.yml: retry the slow health check
    - name: Health check (slow - retry until healthy)
      ansible.builtin.shell: 'f="{{ lab }}/{{ inventory_hostname }}.hc"; echo x >> "$f"; test "$(wc -l < "$f")" -ge 3'
      register: hc
      until: hc.rc == 0
      retries: 5
      delay: 0
      changed_when: false

solution/run.sh proves it node-less against four local hosts: the deploy survives the
injected failure on db1 (rescued, the play not failed); rescue ran only on db1 while
always cleaned up every host; the slow health check was retried until healthy;
ignore_errors and failed_when kept the play green; the notified handler ran; a bad
deploy_env failed fast and deployed nothing; any_errors_fatal aborted the rollout before
it reached anyone; and force_handlers ran the pending handler despite a later failure.

## The three questions

**a. Why validate at the gate, and assert versus a plain when.**

Validating at the gate is cheaper because a precondition checked before you act costs one
quick evaluation, while an error discovered mid-run costs whatever you have already changed
plus the work of undoing it and the risk that you cannot fully undo it. If deploy_env is
garbage and you only find out when a task deep in the play chokes on it, half the fleet may
already carry a broken config and you are now doing damage control; assert at the top makes
the play refuse to start, so the worst case is "nothing happened" instead of "something
half-happened". The difference of intent from a plain when is the crux: when is a *filter* -
it silently skips a task when its condition is false and the play carries on as if nothing
were wrong, which is exactly right when the task is optional ("install this only on
Debian"). assert is a *guard* - it declares a condition that MUST hold for the run to be
valid, and if it does not it stops the play with an error and a message. Use when when the
false branch is a legitimate "not applicable"; use assert (or fail) when the false branch
means "the world is not as I require, do not proceed". Confusing them hides bugs: a when
where you meant an assert lets a run sail past a broken assumption doing nothing, and you
think it succeeded.

**b. rescue versus ignore_errors: recover versus ignore.**

Both let the play carry on past a failed task, but they mean opposite things about the
failure. ignore_errors says "this step failed and I do not care" - the failure is noted
(the recap shows ignored), no recovery happens, and the next task runs as if the failed one
had simply been skipped; it is right only when the step is genuinely optional and its
failure changes nothing that follows (a best-effort metric, a nice-to-have cache warm).
rescue says "this step failed and I must DO something about it" - the block's failure
triggers a recovery path (roll back, restore, alert) and the always path (cleanup), and the
host ends the play in a known, handled state rather than an unknown, half-broken one; it is
right when the failure matters and leaving it unaddressed would be dangerous. The practical
tell is whether the system is left consistent: after an ignored failure, nothing was fixed,
so if the ignored step actually mattered you now have silent corruption; after a rescue, the
block either fully succeeded or was fully rolled back. Confusing them is dangerous because
ignore_errors on something that needed a rescue turns a loud, recoverable failure into a
quiet, permanent one - the deploy "succeeds", the recap is green, and the truth (a
half-applied change no one rolled back) surfaces later, at 3 a.m., far from the cause.

**c. Per-host isolation versus any_errors_fatal.**

The choice depends on how much the hosts depend on one another - whether a failure on one is
a local nuisance or a signal that the whole operation is unsafe to continue. The default,
per-host isolation, is what you want when hosts are independent and a partial success is
still useful: rolling a config out to a hundred web servers, if three are unreachable you
still want the other ninety-seven configured, and the three can be retried later - stopping
the whole run because three nodes were down would be throwing away good work over an
unrelated local problem. any_errors_fatal is what you want when the operation is
all-or-nothing and a single failure means the plan is wrong or the fleet's integrity is at
stake: a coordinated database schema migration where every node must reach the same version,
or a rollout where the first host failing its smoke test means the new build is poisoned -
here letting the other ninety-nine proceed after the first one failed is exactly what ruins
you, because you have now spread a known-bad change across the fleet instead of stopping at
one. Same failure, opposite correct response: per-host when independence makes partial
progress valuable, fail-fast when interdependence makes partial progress a hazard. And when
the truth is in between - "a few failures are tolerable, a lot are not" - max_fail_percentage
lets you set the line.
