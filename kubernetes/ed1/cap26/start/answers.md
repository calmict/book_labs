# Chapter 26 — Answers

## The auditor's first sync

    # paste here: application web sync=Synced health=Healthy, web at 1 replica

## Drift and self-heal

    # paste here: after scaling to 3, OutOfSync, then back to 1

## Declarative rollback

    # paste here: the bad commit takes web to 5, git revert brings it to 1,
    # and git log showing the revert commit on top

## The three questions

**a. The GitOps principle (26.1): why Git as the single source of truth,
what changes versus kubectl apply by hand, and why is ArgoCD's pull model
better than a pipeline that pushes?**

_(your answer)_

**b. Application and reconciliation (26.2-26.3): what is the Application
object, what do Synced/OutOfSync/Healthy mean, what does selfHeal do, and
why is continuous reconciliation the heart of the model?**

_(your answer)_

**c. Declarative rollback (26.4): why roll back with git revert instead of
by hand or helm rollback, what does the Git history give you, and how does
this compare to chapter 24's helm rollback?**

_(your answer)_
