# Chapter 22 — The conveyor belt

**Level:** Cloud Architect
**Estimated time:** 55–65 minutes
**Manual topics:** what CI and CD mean (22.1), the flow: from commit to production (22.2), GitOps: the repository as the single source of truth (22.3), OIDC: the end of static credentials (22.4), the tools and a nod to Atlantis (22.5)

## The idea

For twenty-one chapters you ran the commands: plan, apply, test. This chapter —
the last — takes them out of your hands and puts them on a **conveyor belt**. In
one end goes a commit; out the other comes infrastructure in production. And along
the belt, automatically, chapter 21's pyramid fires: form, consistency, security,
behaviour. Nobody applies by hand; nobody forgets a check.

The belt has two stretches. The first is **CI** (Continuous Integration): on every
*proposed* change — a pull request — the belt runs the checks and produces a
*plan*, the broadcast of what would change. It is the gate: if a check fails, the
door stays shut, and nobody argues with the machine. The second is **CD**
(Continuous Delivery/Deployment): when the change is *approved and merged* into the
main branch, the belt runs the apply. Proposing and delivering become two separate,
automatic acts — plan on the PR, apply on the merge.

Under it all is a principle, **GitOps** (22.3): the repository is the *single
truth*. It is not reality that dictates what exists; it is git. If someone touches
the infrastructure by hand, the belt's next pass notices and *pulls it back* to
what the code says. You will see it with your own eyes.

And one last thing the belt must not carry with it: the keys. Static credentials —
a cloud key pasted into the CI's secrets — are the old curse. **OIDC** (22.4)
abolishes them: the belt keeps no permanent key, it shows a *badge* valid for a
single run.

## Goals

By the end you will be able to:

- tell CI from CD, and map "plan on the PR / apply on the merge" onto the two
  stretches;
- read and complete a pipeline (GitHub Actions) that automates chapter 21's
  pyramid;
- explain GitOps and *demonstrate* drift correction: reality pulled back to git;
- say why OIDC replaces static credentials, and recognise its shape in the
  pipeline;
- place the tools (the pipelines, a nod to Atlantis) in the picture.

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md.
- Docker running. Free port: 8140.
- All of Part 6, but above all chapter 21 (the pyramid): here it goes on the belt.

## Your task

### Phase 0 — The belt's two stretches (22.1, 22.2)

In start/ you find the configuration to deliver (a container) and
pipeline.yml.example: a GitHub Actions pipeline with two jobs. Read it as a belt:

- the plan job runs on every pull_request: it is the *gate* — it checks and
  proposes;
- the deploy job runs only on the push to main: it is the *delivery* — it applies.

You will not run it on GitHub (it sits in the exercise folder, not in
.github/workflows/): it is a template to read, complete and adapt to your own repo.
The real test you will do locally, simulating the same steps.

### Phase 1 — The gate: the pyramid on the belt (TODO 1)

The plan job must run, automatically, the checks you ran by hand in chapter 21.
TODO 1 asks you to complete its steps: after the checkout and installing tofu, add
the pyramid's rungs —

    - run: tofu fmt -check -recursive
    - run: tofu init -input=false
    - run: tofu validate
    - run: tofu plan -input=false -no-color

These four steps are chapter 21 put on the belt: they run on *every* proposal,
before a single line touches production.

### Phase 2 — Delivery, and only at the right moment (TODO 2)

The deploy job runs the apply — but applying is an act to be done *only* when the
change is approved and merged, never on a mere proposal. TODO 2 asks you to set the
guard: the job must run only on a push to the main branch.

    if: github.ref == 'refs/heads/main' && github.event_name == 'push'

Without this line, any pull request would apply to production: proposing and
delivering would collapse back into one act. The guard keeps the gate and the
delivery apart.

### Phase 3 — The belt locally: from commit to production

Now simulate the belt on your machine, with the pipeline's own commands. First the
gate (the PR):

    cd start
    tofu fmt -check && tofu init && tofu validate
    tofu plan -out tfplan

If it all passes, the gate opens. Then the delivery (the merge):

    tofu apply tfplan
    curl -s localhost:8140 | grep -o '<title>.*</title>'

You have just walked the belt by hand: the same exact steps that, in CI, fire by
themselves on every commit.

### Phase 4 — GitOps: who is right, git or reality? (22.3)

Now the proof of the principle. Someone touches the infrastructure by hand —
deletes the container on the sly:

    docker rm -f cap22-app

Reality has drifted from git. Run the belt again:

    tofu plan

The plan does not say "fine as is": it says Plan: 1 to add. The belt *knows*
reality has drifted, and proposes to pull it back to the code. Apply:

    tofu apply
    curl -s localhost:8140 | grep -o '<title>.*</title>'

The container is back. This is GitOps: the hand edit did not win — the repository
won. Reality chases git, not the other way round. Chapter 11 showed us the state as
*memory*; GitOps goes one step further: the versioned code is the *will*, and the
belt enforces it continuously.

### Phase 5 — The badge, not the key: OIDC (22.4, reading)

Look in pipeline.yml.example at the deploy job and the line permissions: id-token:
write, with the (commented) example of configure-aws-credentials assuming a role.
This is OIDC: instead of pasting a permanent cloud key into the CI's secrets —
which, if it leaks, is valid forever — the belt asks the cloud for a
*short-lived token*, valid for that single run, tied to that repository and that
workflow. No key to keep, no key to revoke. It is the last piece of chapter 20's
work on secret security, carried into the pipeline: the best credential is the one
that does not exist at rest.

### Phase 6 — The end of the journey (22.6)

Twenty-two chapters ago, an infrastructure was a set of unrepeatable clicks —
chapter 1's snowflake. Now it is code: described, versioned, validated, tested,
encrypted, and delivered by a belt nobody touches by hand. You have closed the
circle. From here on you design the digital city — and the belt builds it.

### Cleanup

    tofu destroy
    docker rm -f cap22-app 2>/dev/null

## Definition of done

- You completed, in pipeline.yml.example, the four steps of the plan job (TODO 1)
  and the guard of the deploy job (TODO 2).
- Locally, the fmt/init/validate/plan sequence passed, and apply delivered the
  container on 8140.
- Deleting the container by hand, tofu plan said 1 to add, and apply pulled it back
  (drift correction).
- You recognised, in the pipeline, permissions: id-token and the role assumed via
  OIDC (no static key).
- You answered the three questions in answers.md.

## The three questions

**a.** CI and CD on the belt: why does the plan sit on the pull request and the
apply on the merge, and not both together? What, in practice, does separating the
gate (propose) from the delivery (apply) protect — and why is chapter 21 the
natural content of the first stretch?

**b.** GitOps and drift: in Phase 4 you deleted the container by hand and the belt
pulled it back. Explain in what sense "the repository is the single truth": who
wins between a manual change and the versioned code, and why is it a *desirable*
property and not a limitation? Connect it to chapter 11's state (memory) and
chapter 6's plan (code versus reality).

**c.** The badge versus the key: why is a static credential pasted into the CI's
secrets dangerous, and how does OIDC solve the problem at the root (what makes an
OIDC token different from a key)? And, closing the manual: of the twenty-two
chapters, which principle would you carry as the first commandment into your next
real project — and why?
