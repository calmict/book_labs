# Chapter 28 - Answers (model solution)

## The three TODOs

    # TODO 1 (28.3) - the deploy job template, every reference resolving
    - name: deploy
      project: infra-playbooks
      inventory: production
      playbook: deploy.yml
      credentials: [deploy-ssh]
      limit: webfarm

    # TODO 2 (28.4) - least privilege: a scoped role on a specific resource
    rbac:
      - team: deployers
        role: execute
        resource: job_template:deploy

    # TODO 3 (28.5) - the workflow wired, with a failure path to rollback
    workflows:
      - name: release
        nodes:
          - id: n_deploy
            job_template: deploy
            success_nodes: [n_smoke]
            failure_nodes: [n_rollback]
          - id: n_smoke
            job_template: smoke-test
            failure_nodes: [n_rollback]
          - id: n_rollback
            job_template: rollback

solution/run.sh is the pre-import gate, all offline, no AWX required. It syntax-checks the project's
three playbooks (the job templates point at playbooks that really exist and are well formed), runs the
validator on the completed graph (references resolve, the secret is referenced not stored, the RBAC
grant is scoped, the workflow is a valid DAG with a failure path to rollback), and then feeds the
validator four broken graphs - a dangling reference, an over-broad grant, a plaintext secret, a
workflow with no rollback path - and requires each to be rejected. That is exactly what AWX, or your
review, would reject on import.

## The three questions

**a. Why packaging a run into a job template lets a non-expert launch safely.**

Because a job template freezes every dangerous decision in advance and leaves the operator only the
safe one: press the button. The playbook, the project it comes from, the inventory it targets, the
credentials it authenticates with, the limit it is allowed to touch - all are bound by whoever built
the template, reviewed in git, and fixed. The person launching does not choose which hosts, does not
hold the SSH key, cannot point the play at production-by-accident, cannot smuggle in a different
playbook: those choices are not theirs to make. So a first-line operator, or an on-call engineer at 3am,
can run a deploy they do not fully understand and still cannot cause the failures that come from
misusing the tool, because the tool has been pre-aimed. Give that same person a terminal with the same
playbook and you give them the whole loaded weapon: the raw ansible-playbook command takes -i, -e,
--limit, a credential on disk, any playbook in the repo - every one of them a way to run the right play
against the wrong target with the wrong data under the wrong identity, with nothing between the mistake
and production. The template is the difference between a cockpit and a pile of engine parts: same
flight, radically different odds of a crash. What you lose at the terminal is not power - it is every
guard rail that made the power safe to hand out.

**b. Least privilege: a concrete incident, and why broad roles gut the audit.**

An execute-on-the-deploy-template grant lets the deployers team do exactly one thing: run that one
template, against its pre-bound inventory, with its pre-bound credential. Admin-over-the-organisation
lets them do everything - edit any template, repoint any inventory, read or replace any credential,
grant themselves more, delete history. The incident the narrow grant prevents and the broad one does
not: a deployer's account is phished. With execute-on-deploy, the attacker can trigger a deploy of the
already-reviewed release to the web farm - noisy, bounded, reversible. With org-admin, the attacker
edits the deploy template to run their own playbook, against production, using the machine credential
the platform will happily inject, and turns off the audit trail on the way out - a full compromise from
one stolen seat. Same phish, two completely different blast radii, and the difference is only the width
of the grant. Broad roles also gut the audit for a subtler reason: audit answers "who could have done
this?" and "who did?". When everyone is admin, the first answer is always "everyone", so a log entry
stops narrowing anything - it records that a change happened but not that only the right people were
even able to make it. Least privilege is what makes the audit trail evidence rather than trivia: the
smaller the set of people who *could* touch a thing, the more a record of who *did* actually means
something.

**c. Why a workflow with no failure branch is as dangerous as an unbraked rollout.**

Because both keep going forward in exactly the situation where going forward is the wrong move. A
workflow that only wires success edges says: deploy, then smoke-test, then... and if the deploy fails,
it simply stops - leaving the farm in whatever half-changed, failed state the deploy left it in, with
no automated attempt to restore it. That is the same failure as chapter 27's rollout with no
max_fail_percentage: the mechanism advances (or halts) on failure instead of *recovering* from it, so
the broken state persists until a human notices and intervenes. The failure_nodes edge to rollback is
the platform-level equivalent of the always/rescue block inside a playbook (chapter 22): rescue catches
a failed task and runs recovery within one play; failure_nodes catches a failed *job* and runs a
recovery *job* within one workflow. Same shape at two scales - a declared path for "what to do when the
happy path breaks" - and the same principle behind both: orchestration is not only knowing how to go
forward, it is knowing how to come back. A workflow that cannot roll back is a fire drill with no exit
marked.
