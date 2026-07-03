# Chapter 10 — Write Your Own Controller in Twenty Lines (and Learn Why Only One May Run)

> Exercise for **Chapter 10 — Controller Manager and the Reconciliation Loop** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- recognise the heartbeat of the real controllers: the leader-election Leases in kube-system;
- write a working controller yourself (observe–diff–act in twenty lines of shell) and watch it repair your sabotage;
- discover its two structural flaws — polling and the duel between copies — and understand why client-go answers with informers and leader election.

## Prerequisites

- Chapters 7 and 9 completed; the book-labs cluster running (kubectl get nodes must answer).
- The provided start/minictl.sh file, to be completed: the first exercise of the series with a real starting file to fill in.

## Instructions

1. The professionals first. Look at who holds the control plane locks, and their heartbeat:

       kubectl get leases -n kube-system
       kubectl get lease kube-controller-manager -n kube-system -o yaml

   Note holderIdentity and renewTime; run it again after ten seconds: renewTime moved forward. The leader proves it is alive by renewing its lease.
   (Note: on minikube this lease does not exist — its single-node control plane runs with --leader-elect=false. This step needs kind; the rest of the exercise works anywhere.)

2. Your turn. Copy start/minictl.sh into a working folder and open it: it is a maimed controller, with the observe–diff–act structure and three TODOs. Complete it: OBSERVE (count the pods labelled app=minictl, ignoring the Terminating ones), DIFF against the desired state (2), ACT (create one if some are missing; if there are too many, delete one — picking a victim that is not already dying). Twenty lines, nothing more is needed.

3. Make it executable and start it in one terminal:

       chmod +x minictl.sh
       ./minictl.sh

   On its first tick it creates the two pods. Now sabotage from a second terminal, chapter 7 style:

       kubectl delete pod <one-of-the-two>

   Your controller notices the difference and repairs it. Try the excess too: create a third pod by hand with the app=minictl label and watch it get pruned. You are the controller-manager now.

4. First flaw: polling. Your script hits the API every two seconds even when nothing changes — multiply that by a thousand controllers and the apiserver drowns. The real controller-manager uses chapter 9's watch connection (step 6) plus a local cache: that is client-go's informers. Note the difference for the final questions.

5. Second flaw: the duel. Stop the controller, delete the remaining pods, and start TWO copies of minictl.sh in two terminals, as close to the same instant as you can (so their ticks stay aligned). When the two pods are up, delete one and watch the mess: both copies see the hole, both act, the pods become 3, then both trim — possibly the same pod. Two thermostats on the same radiator. (If they do not collide at the first try, that is timing luck: stop everything and restart them together.) Stop the copies and reflect.

6. You already saw the professionals' solution in step 1: before acting, each copy tries to acquire the lease; only one succeeds and the others warm the bench. One active thermostat at a time, takeover only if the incumbent stops renewing.

   The three questions for answers.md: (a) point at the observe, diff and act lines of your script and map them onto what the ReplicaSet controller did in chapter 7; (b) why does polling not scale, and what do client-go's informers and cache change? (c) describe step 5's duel and how leader election prevents it: who renews the lease, and what happens if it stops?

7. Tear down the lab: stop the scripts (Ctrl-C) and:

       kubectl delete pods -l app=minictl

## Definition of "done"

- [ ] You saw the controller-manager lease's renewTime move forward.
- [ ] Your minictl.sh recreates the deleted pod with no human intervention and prunes the excess.
- [ ] You provoked and described the duel between two copies.
- [ ] answers.md answers the three questions.
- [ ] No app=minictl pods left and scripts stopped.
