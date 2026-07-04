# Chapter 20 — Answers (model solution)

## The marriage and the spinster

    manual-pv   50Mi   RWO   Retain   Bound   default/bride   manual
    bride       Bound  manual-pv
    spinster    Pending                        manual

## The automatic matchmaker

    cloud   Bound   pvc-bf2b0c40-...   30Mi   RWO   standard
    standard (default)   rancher.io/local-path   Delete   WaitForFirstConsumer
    manual-pv   Retain  |  pvc-bf2b0c40-...   Delete

## Two different deaths

    (after deleting the claims)
    manual-pv   50Mi   RWO   Retain   Released   default/bride   manual
    (the pvc-... volume is gone)
    docker exec <node> cat /tmp/manual-pv/dote.txt  ->  dote

## The three questions

**a. On which criteria does the binder marry a PVC to a PV, why is it
1:1, and what was the spinster waiting for?**

The binder looks for a PV whose storageClassName matches the claim's,
whose accessModes include the requested ones, and whose capacity is at
least the requested size — bride's 30Mi fit manual-pv's 50Mi (and got all
50: capacity is not sliced). The bond is exclusive by design: a PV carries
one claimRef, because a volume shared between unaware claimants would be
data corruption by construction. The spinster was waiting for the only
thing that can unblock a static Pending: a new Available PV of the manual
class — created by an administrator, or freed by a divorce that in this
class never happens automatically.

**b. The two deaths: when do you want Retain, what is the risk of the
Delete default, and how do you make a Released PV Available again?**

Delete is the right default for disposable, provisioner-made storage: the
claim disappears, the volume and its backing disk go with it, no orphans,
no bills. Its risk is exactly its virtue: a fat-fingered kubectl delete
pvc IS a data deletion — on a database claim it is a disaster with a
one-line trigger. Retain is for data that must outlive any object:
the volume survives as Released, unremarriable because the dead claim's
claimRef is still engraved. To make it Available again a human must
intervene deliberately: verify or clean the data, then remove the
claimRef (kubectl patch pv ... claimRef null) — friction that is not a
bug, it is the whole point.

**c. CSI, CRI, CNI: why interfaces instead of implementations, and where
did you see the provisioner-as-controller pattern?**

Because storage, runtimes and networks are markets, not features: baking
one vendor into the kubelet would freeze the ecosystem and bloat the core
(the old in-tree volume plugins proved it). With a contract — CRI for "run
this container" (chapter 5), CNI for "wire this pod" (chapter 6), CSI for
"provision, attach, mount this volume" — anyone can compete without
touching Kubernetes, and the cluster speaks to all of them the same way.
The pattern you saw is the other half of the trick: the local-path
provisioner is an ordinary controller doing observe-diff-act on claims
(it watched cloud appear, created the volume, wrote the binding), exactly
like chapter 10's minictl — proof that even the storage subsystem is just
objects, watches and controllers all the way down.
