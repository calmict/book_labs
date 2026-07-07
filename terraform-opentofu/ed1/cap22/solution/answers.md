# Chapter 22 — Answers (model solution)

## The belt, locally (Phase 3)

    # gate: fmt -check PASS, init PASS, validate PASS, plan saved
    # delivery: apply delivered, curl on 8140 -> Welcome to nginx

## GitOps drift (Phase 4)

    # after docker rm -f cap22-app:
    Plan: 1 to add, 0 to change, 0 to destroy.
    # after apply: the container is back, the service answers again

## The three questions

**a. CI and CD on the belt.**

plan sits on the pull request and apply on the merge because proposing a change
and delivering it are different acts with different risk. On a PR you want to SEE
what would happen — run the pyramid, produce a plan, let a human review the diff —
without touching anything real; that is the gate, and it can run on every push,
even from a fork, safely, because it changes nothing. apply is the act that
mutates production, so it must happen only once, after the change is reviewed and
merged into the branch that represents "what should be live". Separating them
protects production from two things: an unreviewed change reaching reality, and an
apply firing on a proposal that was never approved. Chapter 21 is the natural
content of the first stretch because the gate's whole job is to check — form,
consistency, policy, behaviour — and those four are exactly the pyramid, now
automatic on every proposal instead of hoped-for by hand.

**b. GitOps and drift.**

The repository is the single truth in the sense that the desired state of the
world lives in git, and the pipeline's job is to make reality match it — not to
record whatever reality happens to be. When I deleted the container by hand,
reality and git disagreed; the next pass planned "1 to add" and apply pulled
reality back. The versioned code won, and the manual change was undone. That is
desirable, not limiting, because it makes the system auditable and recoverable: to
know what is running you read git, to change what is running you commit (reviewed,
tested, reversible), and out-of-band tinkering cannot silently persist — it is
detected and corrected. It builds on two earlier ideas. Chapter 11 gave the state
as MEMORY: what Terraform believes exists. Chapter 6's plan compared code against
reality to compute a diff. GitOps closes the loop: the versioned code is the WILL,
the plan is the continuous comparison, and the belt is the enforcement that keeps
memory, code and reality converging — forever, not just once.

**c. The badge versus the key.**

A static credential pasted into the CI's secrets is dangerous because it is a
long-lived, high-privilege key sitting in a place many people and many workflows
can reach: if it leaks — a compromised action, a logged value, a careless fork —
it is valid until someone notices and rotates it, and it grants whatever it grants
to anyone who holds it. OIDC fixes this at the root by removing the stored key
entirely: the CI proves its identity (this repo, this workflow, this run) to the
cloud, which mints a token that lives for minutes and is scoped to exactly that
run. What makes an OIDC token different from a key is that it is short-lived,
audience-bound and identity-bound: it cannot be reused later, cannot be lifted and
used elsewhere, and needs nothing at rest to steal — the best credential is the one
that does not exist until it is needed and expires right after. As the manual's
first commandment I would carry chapter 1's lesson made total by chapter 22:
infrastructure is code, and reality must equal the code — everything else (state,
modules, tests, encryption, the pipeline) is machinery to keep that one promise
true. If reality can drift from a reviewed, versioned description, you do not have
infrastructure as code; you have a snowflake with extra steps.
