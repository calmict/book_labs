# Chapter 16 — Answers (model solution)

## Crowd versus registry

    crowd-66c788cb8b-68pws  ->  deleted  ->  crowd-66c788cb8b-gkk26
    (a stranger took the seat)
    diary-0, diary-1, diary-2   (born strictly in this order)

## The diary

    diary-1 alive at Sat Jul  4 06:38:11 UTC 2026   <- first life
    diary-1 alive at Sat Jul  4 06:38:47 UTC 2026   <- reborn, same disk
    (and after deleting/recreating the WHOLE StatefulSet, diary-0 still
     opens with the very first line of its very first life)

## The disks

    data-diary-0   Bound   10Mi
    data-diary-1   Bound   10Mi
    data-diary-2   Bound   10Mi
    (identical list before and after deleting the StatefulSet)

## The three questions

**a. Fungible versus identity: why can a database not live in a
Deployment?**

A Deployment's pods are interchangeable by design: random names, any
replica can serve any request, and a replacement is a brand-new stranger.
A database replica is the opposite of a stranger: it owns a specific slice
of data on a specific disk, its peers know it by name, and its role
(primary, follower, voter) is attached to that identity. The lab showed
the three ingredients a Deployment cannot give: a stable name (diary-1
reborn as diary-1), a personal disk that follows the name
(volumeClaimTemplates), and a stable address (the headless Service DNS).
Give a database random names and shared-nothing disks assigned at random,
and every restart is a corruption lottery.

**b. Why is the 0→1→2 order (and the reverse descent) vital for quorum
systems? Connect it to chapter 8.**

Chapter 8 showed that a quorum cluster is bootstrapped by members joining
one at a time: each newcomer must find the existing members, be added to
the member list, and sync before the next one arrives (remember the etcd
learner waiting to be started). The StatefulSet encodes exactly that
liturgy: diary-1 does not exist until diary-0 is Ready, so member 0 can
initialise the cluster and each successor has a stable predecessor to
contact (diary-0.diary...). The reverse descent matters just as much:
scaling down removes the highest ordinal first, so the founding members —
the ones everyone's configuration points at — are the last to go, and the
quorum shrinks gracefully instead of decapitating itself.

**c. Why do the PVCs survive the StatefulSet's deletion? Benefits, risks,
and how to really clean up.**

Because the alternative is unforgivable: a fat-fingered delete of a
controller must never take terabytes of data with it. Storage and workload
have different lifecycles by contract — the claim data-diary-0 belongs to
the IDENTITY diary-0, not to the current StatefulSet object, which is why
the recreated set found every diary intact. The risk is the mirror image:
orphan disks that keep costing money and holding stale data long after the
application is gone, invisible to whoever only checks pods. The real
cleanup is explicit and two-step, delete the StatefulSet and then the
PVCs (newer clusters can automate it with persistentVolumeClaimRetentionPolicy,
whenDeleted: Delete — an opt-in, because the safe default is to keep).
