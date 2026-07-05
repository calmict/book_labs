# Chapter 26 — Answers (model solution)

## The auditor's first sync

    application: sync=Synced health=Healthy
    web in demo: 1 replica (created by ArgoCD, not by hand)

## Drift and self-heal

    scaled web to 3 by hand; sync is now OutOfSync
    self-healed back to 1 replica

## Declarative rollback

    a bad commit set replicas to 5 in the ledger...
    ArgoCD obeyed the ledger: web is at 5 (the book is law, even when wrong)
    git revert struck the line out; the auditor propagates it...
    web back to 1 replica
      fd13c8f Revert "scale web to 5 (oops)"
      f443b4f scale web to 5 (oops)
      92dbc20 initial: web at 1 replica

## The three questions

**a. The GitOps principle (26.1): why Git as the single source of truth,
what changes versus kubectl apply by hand, and why is ArgoCD's pull model
better than a pipeline that pushes?**

GitOps makes ONE place authoritative: a Git repository holds the desired
state of the cluster, and the live cluster is treated as a derived,
disposable copy of it. Compared to running kubectl apply by hand, this
changes everything about who knows the truth. With hand-applied manifests,
the real state lives only in the cluster; what is in anyone's local files
is a guess, drift accumulates silently, and "what is actually deployed and
why" has no single answer. With Git as the source of truth, the answer is
always "read the repo": every change is a commit — reviewed, timestamped,
attributable — and the cluster is guaranteed to reflect it because an agent
continuously enforces it. The PULL model matters for the same reason it did
for Prometheus in chapter 25: ArgoCD runs INSIDE the cluster and reaches
out to Git to pull the desired state, rather than an external CI pipeline
reaching IN to push changes. Pull means the powerful production credentials
never leave the cluster — no pipeline holds a cluster-admin kubeconfig that
could be leaked; the cluster only needs read access to a repo. It also
means the cluster keeps reconciling on its own even if the pipeline is down,
and a new cluster can bootstrap itself by simply being pointed at the repo.

**b. Application and reconciliation (26.2-26.3): what is the Application
object, what do Synced/OutOfSync/Healthy mean, what does selfHeal do, and
why is continuous reconciliation the heart of the model?**

The Application is a Custom Resource that gives ArgoCD an assignment: which
repo and path hold the desired state (source), where to apply it
(destination cluster + namespace), and how to behave (syncPolicy). ArgoCD
then reports two independent things. SYNC status compares the ledger to the
live cluster: Synced means they match, OutOfSync means they diverge (Git
changed, or the cluster did). HEALTH status is about the resources
themselves: Healthy means the Deployment's pods are actually up and ready —
a distinct question from whether the manifest matches Git. selfHeal governs
what happens on OutOfSync caused by a CLUSTER change: with selfHeal on, when
someone scales the Deployment by hand, ArgoCD sees the divergence from the
ledger and re-applies the ledger's value, undoing the manual edit — which
is exactly what you watched happen. This is why continuous reconciliation,
not a one-shot apply, is the heart of GitOps: it is the same controller
pattern as chapter 10 (observe desired vs actual, act to close the gap), run
forever. Drift is therefore not treated as an error to panic over but as the
NORMAL, expected condition the loop exists to erase — the system assumes the
world will always drift and makes converging it back the steady state.

**c. Declarative rollback (26.4): why roll back with git revert instead of
by hand or helm rollback, what does the Git history give you, and how does
this compare to chapter 24's helm rollback?**

In GitOps you never fix the world directly, because the world is not the
source of truth — the ledger is. If you scaled the Deployment back by hand,
selfHeal would immediately undo your fix, because Git still says the wrong
thing; and even if it did not, you would have introduced an untracked change
that no one can review or reproduce. So the rollback happens where the truth
lives: git revert creates a NEW commit that undoes a previous one, you push
it, and the auditor propagates it to the cluster. The win is the Git history
itself: every deploy and every rollback is a signed, timestamped, reviewable
commit, so you get a complete audit trail (who changed what, when, and why),
trivial reproducibility (check out any commit to recreate that exact state),
and rollback that is just ordinary version control rather than a special
operation. Compared to chapter 24: helm rollback also stacks revisions and
can undo, but it stores that history as Secrets INSIDE one cluster — local,
cluster-scoped, invisible to code review. In a GitOps world that in-cluster
history is not the source of truth; the Git repo is. Helm still packages and
templates the manifests, but which revision is "live" is decided by what is
committed to Git and enforced by ArgoCD — the ledger, not the cluster's own
memory, has the final word.
