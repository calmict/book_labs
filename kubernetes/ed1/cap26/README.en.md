# Chapter 26 — The Ledger and the Auditor (ArgoCD and GitOps)

> Exercise for **Chapter 26 — ArgoCD and GitOps** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Cloud Architect

## Objectives

By the end of this lab you will be able to:

- understand the GitOps principle: Git is the ledger, the single source of truth for what must exist in the cluster; nobody touches the world by hand, you write in the ledger;
- give the assignment to a tireless auditor (ArgoCD) with the Application object, and watch it make the cluster match the ledger (sync), notice any divergence (drift) and correct it on its own (self-heal);
- roll back the declarative way: you do not fix the world, you correct the ledger with git revert, and the auditor propagates the correction.

## Prerequisites

- Chapter 24 (Helm: in the real world ArgoCD is also installed via a chart; here we install it via manifests to see the pieces) and Chapter 15 (rollout/rollback by hand: here Git commands the rollback).
- kind installed. WARNING: ArgoCD installs cluster-wide resources (CRDs, ClusterRoles); to avoid polluting the book-labs cluster, this lab uses a dedicated throwaway cluster (book-labs-gitops), torn down at the end with a single command.
- In start/: gitserver.yaml (given, the in-cluster ledger) and application.yaml (TODO, the auditor's assignment).

## Instructions

1. The building site. Create the dedicated cluster, install ArgoCD and start the git server that hosts the ledger:

       kind create cluster --name book-labs-gitops
       kubectl create namespace argocd
       kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
       kubectl -n argocd wait --for=condition=Available deploy --all --timeout=300s
       kubectl apply -f gitserver.yaml
       kubectl -n gitops rollout status deploy/gitserver

   (--server-side avoids the "annotation too long" error on ArgoCD's largest CRD.) The git server hosts a repo with manifests/web.yaml: a Deployment web at 1 replica. That is the ledger.

2. The auditor's assignment. Complete application.yaml: an Application object that tells the auditor which ledger to read and where to apply it. In source put the repoURL (git://gitserver.gitops.svc.cluster.local:9418/app.git), the path (manifests) and targetRevision (main); in destination the demo namespace; and a syncPolicy automated with selfHeal and CreateNamespace. Apply it and watch the auditor get to work:

       kubectl apply -f application.yaml
       kubectl -n argocd get application web -o wide
       kubectl -n demo get deploy web

   Within seconds: Synced and Healthy, and web exists with 1 replica. Nobody ran kubectl apply on the Deployment: ArgoCD did, reading the ledger.

3. The auditor never sleeps (drift and self-heal). Try to command the world by hand:

       kubectl -n demo scale deploy web --replicas=3
       kubectl -n argocd get application web -o jsonpath='{.status.sync.status}'
       kubectl -n demo get deploy web -w

   For an instant it is OutOfSync at 3 replicas, then the auditor puts it back to 1: the manual change is undone. In GitOps the world does not rule — the ledger does.

4. Correct the ledger, not the world (git revert). The repo lives in the cluster: make a bad commit by exec-ing into the git server, then watch ArgoCD obey the ledger even when it is wrong:

       kubectl -n gitops exec deploy/gitserver -- sh -c 'cd /work && sed -i "s/replicas: 1/replicas: 5/" manifests/web.yaml && git commit -qam "scale web to 5" && git push -q origin main'
       kubectl -n argocd annotate application web argocd.argoproj.io/refresh=hard --overwrite
       kubectl -n demo get deploy web -w

   The world goes to 5 replicas: the ledger is law. Now do NOT scale by hand — correct the ledger:

       kubectl -n gitops exec deploy/gitserver -- sh -c 'cd /work && git revert --no-edit HEAD && git push -q origin main'
       kubectl -n argocd annotate application web argocd.argoproj.io/refresh=hard --overwrite
       kubectl -n demo get deploy web -w

   The auditor puts the world back to 1. The rollback is a line struck out in the ledger (git revert), not a manual intervention: it stays in the history, signed and traceable.

5. Tear the building site down (one command, no cluster-wide residue):

       kind delete cluster --name book-labs-gitops

## The questions for answers.md

- (a) The GitOps principle (26.1). Why Git as the single source of truth, and what changes compared to a kubectl apply run by hand? ArgoCD runs inside the cluster and pulls from Git, the way Prometheus in chapter 25 went and fetched the metrics: what is the advantage of pull over a pipeline that pushes (with the production kubeconfig in hand)?
- (b) Application and reconciliation (26.2–26.3). What is the Application object and what do Synced / OutOfSync / Healthy mean? What does selfHeal do exactly when someone touches the cluster by hand, and why is continuous reconciliation (not a one-shot apply) the heart of the model? Is drift an error or is it normal?
- (c) Declarative rollback (26.4). Why in GitOps do you roll back neither by hand nor with helm rollback, but with git revert? What does having the history in Git give you (audit, who-changed-what, repeatability)? Tie to chapter 24: helm rollback stacks revisions in Secrets; git revert stacks commits in the ledger — which of the two is the source of truth in a GitOps world?

## Definition of "done"

- [ ] ArgoCD installed and the git server (the ledger) running on the dedicated cluster.
- [ ] Application completed: web Synced and Healthy, 1 replica, created by ArgoCD.
- [ ] Drift and self-heal: the manual scale to 3 is undone, back to 1.
- [ ] git revert: the bad commit takes the world to 5, the revert brings it back to 1.
- [ ] answers.md answers the three questions; the dedicated cluster has been deleted.
