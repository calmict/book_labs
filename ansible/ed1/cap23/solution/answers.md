# Chapter 23 - Answers (model solution)

## The completed TODOs

    # TODO 1 (23.3) - the sloppy playbook, cleaned so ansible-lint passes:
    #   - the play and every task are named
    #   - modules use the FQCN (ansible.builtin.file/command/copy)
    #   - octal modes are quoted strings with a leading zero ("0755", "0644")
    #   - every command declares changed_when
    # (see solution/site.yml)

    # TODO 2 (23.5) - the read task made check-mode safe:
    - name: Read the current config (read-only, safe in check mode)
      ansible.builtin.command: cat {{ conf }}
      register: current
      changed_when: false
      failed_when: false
      check_mode: false

    # TODO 3 (23.3) - .ansible-lint pins the project profile:
    profile: production

solution/run.sh proves the three-level net node-less on localhost: --syntax-check passes;
ansible-lint passes on the clean playbook at the declared production profile; ansible-lint
CATCHES the sloppy start playbook; the read task is check-mode safe; --check --diff shows
the change but writes nothing; and the real run writes conf.txt and is idempotent on a
rerun.

## The three questions

**a. Why use the three levels in order and stop at the first failure.**

Because they form a funnel where each level is more expensive and catches a different, larger
class of problem, so running them cheapest-first gives you the fastest feedback and wastes no
work. --syntax-check is almost free - it parses the structure without touching a node or even
resolving variables - and it catches the gross errors (a mis-indented key, an unknown
directive, a broken bracket) that would make everything downstream meaningless; there is no
point asking ansible-lint's opinion on a file that does not even parse. ansible-lint is the
next step up: it does not run anything either, but it evaluates hundreds of rules about style
and correctness that syntax-check knows nothing about (missing names, short module names, a
command with no changed_when), so it catches errors of *judgement*, not just of typing. Check
mode is the richest and the costliest - it actually connects and simulates the whole run
against the real inventory - and only it can tell you what would concretely *change* on the
targets; it is the only one that sees the effect, but it needs the environment and time the
other two do not. Stopping at the first failure matters because a failure at a cheap level
usually invalidates the richer ones: if the YAML does not parse, ansible-lint's report is
noise; if lint says the playbook is malformed in ways that change behaviour, the check-mode
diff may be misleading. Fix the cheap thing, re-run, climb. Each level catches what the one
below cannot, and each below spares you paying for the one above until it is worth it.

**b. Why check mode is more than a dry run, and what --diff adds.**

A plain "dry run that prints the commands" tells you *what Ansible would attempt*; check mode
tells you *what would actually change*, which is a different and stronger claim. Ansible does
not just echo the tasks - it evaluates each module in check mode against the real current
state of the target and reports ok versus changed per task, so a task whose desired state
already matches reality reports ok (nothing to do) and only genuinely divergent tasks report
changed. That means the check-mode summary is a preview of the *actual* effect, convergence
included: run it against a fleet already in the desired state and it says changed=0, run it
after someone edited a file by hand and it flags exactly that host. --diff sharpens this from
a count into content: instead of "the config task would change", it shows the literal before
and after lines - the two lines that would be added, the value that would flip - so you review
not "something will change" but "these exact bytes will change". That changes how you read a
playbook because it turns review from trusting the code to inspecting the outcome: you catch
the template that would rewrite the whole file when you meant one line, the mode that would
loosen permissions, the variable that resolved to the wrong value - before any of it touches a
real machine. The dry run says "I intend to act"; check mode with --diff says "here is the
change I would make, line by line, and only where it is actually needed".

**c. Why a targeted # noqa, not a project-wide disable.**

Because a rule exists to catch a real class of mistake across the whole project, and turning
it off everywhere to quiet one false positive throws away all the *true* positives it would
have caught tomorrow. A false positive is local: this one task, for a reason you understand
and can write down, legitimately breaks a rule that is right almost everywhere else. A
targeted # noqa: <rule> on that line says exactly that - "I know this rule, I have looked at
this specific case, and here it does not apply" - and it leaves the rule fully active for
every other task, including the ones you have not written yet. A project-wide disable (dropping
the rule from the profile or a blanket skip_list) says something much larger and almost
certainly false: "this rule is never useful here". The day you do that to silence a single
task, you also silence it for the fifty future tasks where it would have caught a genuine bug -
a real unnamed task, a real missing changed_when, a real risky permission - and those bugs now
sail through green. You have traded a visible, documented, one-line exception for an invisible,
undocumented, project-wide blind spot. The targeted, justified exception keeps the safety net
intact and records *why* there is a hole; the wholesale disable quietly cuts a hole in the net
and forgets it was ever there.
