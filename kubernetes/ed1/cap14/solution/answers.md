# Chapter 14 — Answers (model solution)

## The condo

    Fri Jul  3 21:47:15 UTC 2026
    (the writer read via localhost the page served by web, whose content
     is the file the writer itself writes on the shared volume)

## The evidence from the node

    net ns:  writer net:[4026533858] / web net:[4026533858]   <- identical
    pid ns:  writer pid:[4026533964] / web pid:[4026533961]   <- different
    65535   420   314   /pause
    (the janitor, owned by user 65535: one per pod sandbox)

## The glass condo

    PID   USER     TIME  COMMAND
        1 65535     0:00 /pause
        7 root      0:00 httpd -f -p 8080 -h /www
       20 root      0:00 sh -c while :; do date > /www/index.html; ...

## The gatekeeper and the castes

    init-demo   0/1   Init:0/1   ->   1/1   Running
    poor     BestEffort
    middle   Burstable
    royal    Guaranteed

## The three questions

**a. Why the Pod and not the container: use your evidence and explain what
job the pause container does.**

Because some things must be shared to be useful: the two tenants talked
over localhost (one net namespace, proven by the identical inodes) and
exchanged files on the same volume, while keeping private process trees
(different pid inodes). A single container cannot offer that combination;
a Pod is precisely "a group of containers sharing the namespaces that make
them one logical host". The pause container is the janitor that makes it
possible: it starts first, holds the shared namespaces open, and does
nothing else — so that any tenant can crash and be restarted (chapter 12)
without the building collapsing. Kill the tenants and the rooms survive,
because the janitor never leaves.

**b. Init container versus sidecar: what does the Init sequence guarantee,
and when do you need a companion that stays alive instead?**

Init containers run strictly one after another, each to completion, before
any app container starts: the guarantee is ordering — migrations done,
config fetched, gate opened — and the Init:0/1 status makes the wait
visible. But an init container is gone once the app runs: if the companion
must keep working alongside the app (a log shipper, a proxy, a refresher),
you need a sidecar — today expressed as an init container with
restartPolicy Always, which starts before the app AND stays alive with
it. Rule of thumb: prepare once = init; accompany forever = sidecar.

**c. The three castes: where does each end up in the cgroup hierarchy, in
which order do they die under node pressure, and why does Guaranteed mean
protected rather than fast?**

The kubelet files each pod under kubepods in a QoS-named slice: the
besteffort branch (chapter 13 showed it in the path), the burstable
branch, and the guaranteed pods directly under kubepods. Under memory
pressure the eviction of chapter 12 empties them in caste order:
BestEffort first (they promised nothing), then Burstable exceeding their
requests, Guaranteed last. Guaranteed is not faster — its limits are a
ceiling like anyone else's (chapter 3's throttling still applies): what
requests=limits buys is predictability, a reservation the scheduler
honoured in full and the strongest claim to stay when the node starves.
Protection, not performance.
