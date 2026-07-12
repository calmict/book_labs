# Chapter 26 — The stage machinery

**Level:** Cloud Architect

Chapter 25 gave you the speed to serve a thousand nodes. But at that scale one thing has already
changed under your feet: **it is no longer a person who launches the playbook**. With a thousand nodes
and many hands on the same code, an ansible-playbook typed by hand from someone's laptop is too
fragile — nobody checked the lint, nobody knows which version it starts from, nobody stops an untested
change from reaching production on a Friday evening. The answer is a **stage machinery**: every change
passes through version control, crosses a **pipeline** that validates it on its own (CI), and only an
authorised release crosses the **gate** into production (CD). This chapter builds it: the quality
gates on GitHub Actions, the production gate that opens only on a tag, and the pre-commit hooks that
run the check before the commit even exists.

## Objectives

- What **CI and CD** mean, and why at scale they replace the person who launches (26.1).
- The **foundation**: without version control there is no pipeline (26.2).
- The **anatomy of an Ansible pipeline**: the gates in a row (26.3).
- A concrete pipeline: **GitHub Actions** and the quality gates (26.4).
- **Deploy and the production gate**: who takes the stage, and when (26.5).
- **GitLab CI**: the same pattern, different syntax (26.6).
- Shift left further: **pre-commit hooks**, the same gate before the commit (26.7).
- **Good habits** with CI/CD (26.8).

## Prerequisites

- The chapter 6 venv with **ansible-core**, plus **ansible-lint** (ch. 23) and **pre-commit** (in
  start/requirements.txt).
- The **lint** and **check mode** of chapter 23: here they become the automatic steps of a pipeline.
- The idea of **git** as the foundation: the pipeline reacts to what enters the repository.
- No cloud account and no remote node: the fleet is local, the pipeline runs dry, but the gates are
  real.

## The scenario

start/ is a small Ansible project ready to ship: site.yml (a correct playbook), inventory.ini (a local
host), and a ci/ folder with two ready-made scripts — lint.sh and validate.sh — which are the
**quality gates** (ansible-lint, then syntax-check and check mode). Around this project you build the
stage machinery: a GitHub Actions pipeline and a pre-commit hook, both reusing those same two scripts.
Three gaps leave it incomplete; you close them.

Set up the environment:

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    cd start

### Phase 1 — CI and CD (26.1)

**CI** (Continuous Integration) is: every change, the moment it enters the repository, is integrated
and **validated automatically** — lint, syntax-check, tests — so an error surfaces in minutes, not in
production. **CD** (Continuous Delivery/Deployment) is the next step: a change that has passed every
gate is **delivered**, and — with an authorisation — put into production. At three nodes you launch by
hand and get away with it; at a thousand, with several people, the manual launch is the weak point.
The stage machinery takes the person out of the checking loop and leaves them only where a **decision**
is needed: opening the production gate.

### Phase 2 — The foundation: version control (26.2)

None of this exists without **git**. The pipeline does not react to the files on your disk: it reacts
to what is **committed and pushed** to the repository. The repository is the single source of truth —
the version that runs is the one in the commit, not the one you had open in the editor. And it is git
that gives the production gate its signal: a release **tag** (v1.4.0) is a point in history that says
"this one, and only this one, goes to production". Without versioning there is neither CI (validate
what?) nor CD (deliver what?).

### Phase 3 — The anatomy of a pipeline (26.3)

An Ansible pipeline is a **row of gates**, from cheapest to costliest, each stopping the run if it does
not pass:

    lint          # style and best practice (ch. 23) - fast, always runs
    syntax-check  # the playbook is well formed (ch. 23)
    check mode    # dry run: what would change (ch. 23)
    (molecule)    # the role works on a real system (ch. 24) - more expensive
    deploy        # only if everything above is green AND there is authorisation

The order is deliberate: the fast checks first, rejecting most errors immediately; deploy is **last**
and is protected by a gate. In this exercise the quality gates are lint.sh and validate.sh (molecule
stays reading: you already ran it in chapter 24, but it needs Docker and weighs the pipeline down).

### Phase 4 — GitHub Actions: the quality gates (26.4 — TODO 1)

A GitHub Actions pipeline lives in .github/workflows/ci.yml. It has **jobs**, each job has **steps**.
Open the file: the test job checks out the code, sets up Python and installs the dependencies, but the
two steps that matter — the gates — are missing. Complete **TODO 1**: add the two steps that run the
quality gates on every push —

    - name: Lint
      run: ./ci/lint.sh
    - name: Validate
      run: ./ci/validate.sh

The test job runs on push and pull_request: every change is validated before it can be merged. If
lint.sh or validate.sh exits with an error, the job goes **red** and the pipeline stops. It is chapter
23 made automatic and mandatory: no longer "remember to run the lint", but "you do not get in if the
lint does not pass".

### Phase 5 — Deploy and the production gate (26.5 — TODO 2)

The deploy job is the CD part, and it must run **almost never**: only for a release, only if the gates
are green. Those are two distinct conditions. Complete **TODO 2** in the deploy job —

    needs: test
    if: startsWith(github.ref, 'refs/tags/v')

needs: test chains deploy to CI: if the test job fails, deploy does not even start. The if is the
**production gate**: deploy runs only when what triggered the pipeline is a **release tag**
(refs/tags/v1.4.0), never an ordinary push to a branch. A daily push runs the quality gates but does
**not** touch production; only a deliberate tag crosses it. The workflow also has environment:
production: on GitHub a *protected environment* adds a second gate — a reviewer's **human approval** —
on top of the tag condition. The gate, then, has two forms: a **condition** (the tag) and a **person**
(the approval). Question a.

### Phase 6 — GitLab CI: the same pattern, different syntax (26.6)

GitHub Actions is not the only conductor. **GitLab CI** reads a .gitlab-ci.yml and describes the same
concepts with different words: stages instead of jobs in needs, rules with if: $CI_COMMIT_TAG instead
of the ref guard, script for the commands. The grammar changes, not the sentence: quality gates on
every push, deploy behind a tag-bound gate. Whoever grasps the pattern finds it everywhere — Jenkins,
CircleCI, Drone — because the pattern is the pipeline, not the product.

### Phase 7 — Shift left further: pre-commit hooks (26.7 — TODO 3)

CI catches errors after the push. But why wait for the push? A **pre-commit hook** fires the same gate
on your laptop, **before** the commit exists — the error does not even leave the machine. Open
.pre-commit-config.yaml and complete **TODO 3**: add the hook that reuses the pipeline's very lint —

    repos:
      - repo: local
        hooks:
          - id: ansible-lint
            name: ansible-lint
            entry: ./ci/lint.sh
            language: system
            pass_filenames: false
            files: \.(yml|yaml)$

repo: local means the hook downloads nothing from the internet: it calls the script you already have.
You install it once with "pre-commit install", and from then on every "git commit" runs the lint; if
it fails, the commit is blocked. It is the **same gate** as phase 4, moved even further upstream — the
principle of chapter 23, "shift the check left", taken to its extreme. Question b.

### Phase 8 — Good habits (26.8)

- **The repository is the truth**: what runs is what is committed, not what is on your disk. No manual
  edits on the servers.
- **Gates in a row, cheapest first**: lint before molecule before deploy — reject early, spend late.
- **Deploy is always behind a gate**: never automatic on every push; a condition (the tag) and, for
  production, a person (the approval).
- **The same gate at several levels**: pre-commit on the laptop, CI on the push — so an error meets two
  nets before human review even begins.
- **DRY on the gates**: pipeline and pre-commit reuse the same scripts (ci/), so "green locally" and
  "green in CI" mean the same thing.

## Done when

- The test job of ci.yml runs the two quality gates on every push (TODO 1): lint.sh and validate.sh.
- The deploy job has needs: test and the tag if (TODO 2): it does not start if CI fails, and runs only
  on a release tag.
- .pre-commit-config.yaml has the local ansible-lint hook (TODO 3): the same lint fires before the
  commit.
- The gates **actually bite**: green on the good project, red on a broken playbook — both in the
  pipeline and in the pre-commit hook.

## How it is verified

solution/run.sh proves it, all locally and offline:

1. **The gates bite**: it runs lint.sh and validate.sh on the shipped project (green), then on a
   deliberately broken playbook (a bare command, no name, no changed_when) and requires them to fail —
   the pipeline would go red.
2. **The production gate is correct**: it parses ci.yml and checks that deploy has needs: test and an
   if bound to refs/tags/v; then it shows the rule at work — a branch ref is blocked, a tag ref is
   allowed.
3. **Shift-left works**: it inits a throwaway git repo and runs "pre-commit run": it passes on the
   clean tree, fails the moment a lint violation is introduced — the hook would block the commit. All
   offline (repo: local).

## Reflection questions

**a.** The production gate has two forms: a **condition** (deploy runs only on a refs/tags/v tag) and a
**person** (the approval of a protected environment). Why do you need **both** at scale? Describe an
incident the tag condition alone does not stop but human approval does — and one that approval alone
does not stop but the condition does.

**b.** The same lint runs in three places: on the laptop (pre-commit), on the push (CI) and, ideally,
you run it by hand too. Isn't that redundant? Explain why having the **same gate at several levels**
makes the system both faster *and* safer rather than just slower — and what would be lost by removing
the pre-commit hook and keeping only CI.

**c.** needs: test chains deploy to CI. What would happen, concretely, in a pipeline where the deploy
job does **not** declare needs and runs in parallel with the test job? Why is "deploy depends on the
gates passing" not an optimisation but a **safety condition**?

## Cleanup

Nothing to tear down: no remote node, no container, no cloud account. Close the venv with:

    deactivate

## Where it leads

You have the stage machinery that carries a change from commit to production through the gates
(ch. 26). But the deploy job, so far, is one line of echo: *how* do you actually deliver to a fleet
without taking the service down? **Chapter 27** enters **orchestration and rolling updates** — serial,
delegate_to, pre/post_tasks, rollback — because shipping to a thousand nodes is not "apply to all at
once", but "apply in waves, checking after each, ready to roll back".
