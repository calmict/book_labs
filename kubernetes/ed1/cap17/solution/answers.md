# Chapter 17 — Answers (model solution)

## The watchmen

    before the toleration:  watchman on worker, watchman on worker2  (2/3)
    after the toleration:   worker, worker2, control-plane           (3/3)
    rebirth: watchman-zlwth deleted on worker -> watchman-zfg7x born
    on worker (same post, new soldier)

## The two fates

    countdown   Complete   1/1     (logs: 5 4 3 2 1 liftoff)
    flaky-xjwdk   Error    <- attempt 1
    flaky-gj8ck   Error    <- retry 1
    flaky-gtjcr   Error    <- retry 2
    Warning  BackoffLimitExceeded  job-controller  Job has reached the
    specified backoff limit

## The punch clock

    tick-29719261   Complete   1/1   2s
    tick at Sat Jul 4 09:01:00 UTC 2026

## The three questions

**a. Where is "how many" written in a DaemonSet? Explain the geographic
contract with your evidence.**

Nowhere — and that absence is the whole object. A Deployment answers "how
many copies?" with a number you chose; a DaemonSet answers "where?" with
"everywhere the map allows". The count you observed (2, then 3) was never
declared: it was computed from the nodes, minus the ones whose taints the
pod does not tolerate — adding the toleration did not scale anything, it
enlarged the map. The rebirth proved the second half of the contract: the
replacement did not go wherever there was room (there was room on three
nodes), it went back to the SAME node, because each node owns exactly one
watchman. Add a node tomorrow and a watchman appears on it, unasked: log
collectors, CNI agents and kube-proxy itself (chapter 12) live on this
contract.

**b. Why is restartPolicy Always forbidden in a Job, what does
backoffLimit count, and how does a Job retry differ from a kubelet
container restart?**

Always means "this process must never end" — the exact opposite of a Job,
whose success is DEFINED by termination with exit 0: with Always the
kubelet would resurrect the finished container forever and the Job could
never be judged complete. So a Job only accepts Never or OnFailure.
backoffLimit counts the failed ATTEMPTS the Job controller is willing to
make beyond hope — with Never, each attempt is a brand-new Pod (you saw
three corpses, each a separate pod object, each preserving its logs). A
kubelet restart (chapter 12) is the same Pod, same node, RESTARTS counter
rising, invisible to the controller; a Job retry is a cluster-level event:
new Pod, possibly a new node, and a controller keeping score until the
score runs out — BackoffLimitExceeded, the honest failure.

**c. The trades table.**

Deployment: the stateless crowd — web servers, APIs; answers "how many
copies?". StatefulSet: the registry office — databases, quorum members;
answers "who are you?" (name, disk, address). DaemonSet: the per-node
agent — log collectors, node monitors, CNI; answers "where?" (everywhere,
one each). Job: the finite task — migrations, batch computations, backups;
answers "is it done?" (and may honestly fail). CronJob: the scheduled
foreman — the nightly backup, the hourly cleanup; answers "when?" and
delegates everything else to a Job it manufactures on time.
