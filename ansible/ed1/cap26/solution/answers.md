# Chapter 26 - Answers (model solution)

## The three TODOs

    # TODO 1 (26.4) - .github/workflows/ci.yml, the test job: the two quality gates
    - name: Lint
      run: ./ci/lint.sh
    - name: Validate
      run: ./ci/validate.sh

    # TODO 2 (26.5) - .github/workflows/ci.yml, the deploy job: the production gate
    needs: test
    if: startsWith(github.ref, 'refs/tags/v')

    # TODO 3 (26.7) - .pre-commit-config.yaml: the same lint, before the commit
    repos:
      - repo: local
        hooks:
          - id: ansible-lint
            name: ansible-lint
            entry: ./ci/lint.sh
            language: system
            pass_filenames: false
            files: \.(yml|yaml)$

solution/run.sh proves all three, locally and offline. It runs the two gate scripts on the shipped
project (green) and on a broken playbook (lint goes red); it parses ci.yml and checks the deploy job
needs the test job and is gated on a refs/tags/v release tag, then shows the rule blocking a branch
ref and allowing a tag ref; and it inits a throwaway git repo and runs the pre-commit hook, which
passes on the clean tree and blocks a lint violation - no network, because the hook is repo: local.

One detail worth naming: YAML parses the bare key "on:" as the boolean true (the Norway Problem of
chapter 4, the score that lies), so code that reads the workflow must look the key up as True, not
"on". run.sh does exactly that.

## The three questions

**a. Why the production gate needs both a condition (the tag) and a person (the approval).**

Because they guard against two different failures, and neither covers the other. The tag condition is
a machine rule: deploy fires only from refs/tags/v*, so a routine push, a merge, a bot commit - the
overwhelming majority of repository activity - can never reach production, no matter who does it or
when. That is exactly what a human gate cannot give you: a person cannot reliably not-approve a
thousand pushes a week; attention is the scarce resource, and the condition spends none of it. But the
condition is blind to intent and content: it fires for *any* v-tag, including one cut from a broken
commit, at 2am, by someone who did not mean to release, or a compromised token that tags and pushes.
The environment approval is the human rule: before the deploy job runs, a named reviewer must look and
say yes. It catches the release that is technically valid but wrong to ship now - the Friday-evening
tag, the tag on an unreviewed hotfix, the tag nobody expected. So: the condition stops the 999
harmless events cheaply and automatically (an approval-only gate would drown and rubber-stamp); the
approval stops the 1 valid-looking-but-wrong release (a condition-only gate would wave it through). At
scale you need both because the condition filters volume and the person filters judgement, and each is
blind exactly where the other sees.

**b. Why the same lint at three levels is faster and safer, not just slower.**

Because the three levels differ in *when* they catch, and earlier is cheaper. The pre-commit hook
catches on your laptop, in the second before the commit exists: the error never enters history, never
starts a CI run, never waits in a queue, never asks a reviewer to notice it. That is the fast path -
the tightest possible feedback loop, and it is why the *whole system* is faster with pre-commit, not
slower: the expensive machinery (a CI runner spinning up, a red build, a re-push, a re-review) is the
thing you avoid by paying a few local seconds. But pre-commit is advisory and skippable: it lives on
each person's machine, it can be bypassed (git commit --no-verify), a new contributor may not have run
pre-commit install, and it never runs for a change that arrives by any path other than that laptop. So
it cannot be the *authority*. The CI job is the authority: it runs on the server, on every push, for
everyone, unskippably, and it is what a branch-protection rule can actually require before merge. Take
the pre-commit away and keep only CI and nothing is unsafe - but every trivial lint slip now costs a
full push/CI/red/fix/re-push cycle instead of a local re-edit, and reviewers spend attention on
mistakes a hook would have eaten. Same gate, three levels: the early ones make it fast, the server one
makes it binding. Defence in depth, where depth is measured in time.

**c. What breaks if deploy has no needs, and why the dependency is a safety condition.**

If the deploy job does not declare needs: test, GitHub schedules it independently of the test job, so
the two race in parallel. Concretely: you push a tagged release, the test job starts running lint and
validate, and at the very same moment the deploy job starts shipping to production - it does not wait
to learn whether the quality gates passed, because you never told it to. So a release with a lint
failure, a syntax error, a check-mode surprise, deploys anyway; the red X appears on the test job a
minute later, next to a production that is already broken. needs: test makes the deploy job a
*successor* of the test job: GitHub will not start deploy until test has finished and finished green,
and if test fails, deploy is skipped entirely. That is why it is not an optimisation but a safety
condition - it is the wiring that makes "we validate before we ship" true in fact rather than in
intention. Ordering here is not about speed; it is the causal link that lets CI actually gate CD.
Without it the pipeline still runs every check - it just runs them beside the deploy instead of before
it, which is the same as not running them at all.
