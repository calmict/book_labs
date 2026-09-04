# Chapter 20 — Answers (model solution)

## The completed TODOs

TODO 1 (20.1) completes the static claim with the manual StorageClass,
ReadWriteOnce, and a 30Mi request, so it matches the hand-made PV.

TODO 2 (20.2) gives the dynamic claim the same access mode and size but
deliberately omits storageClassName. The default StorageClass can therefore
provision a new PV for it.

TODO 3 (20.3) changes manual-pv's reclaim policy to Retain. Deleting bride
releases the PV and preserves its data, in contrast with the dynamically
provisioned PV whose Delete policy removes it.

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
