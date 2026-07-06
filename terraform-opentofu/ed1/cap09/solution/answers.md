# Chapter 9 — Answers (model solution)

## The declared unknown (Phase 1)

    + content = (known after apply)

    container id : 312dee78b7e39991452189263f09d0451fb2ec27ce1621c57bdbfdc286413ae7
    internal ip  : 172.17.0.2
    # (yours will differ — they are born at apply time, that is the point)

## The night team (Phase 2)

    ~ restart = "unless-stopped" -> "no"

## The blind eye (Phase 3)

    No changes. Your infrastructure matches the configuration.
    unless-stopped

    # (the plan is quiet AND reality kept the hand-made policy: tolerated,
    # not repaired)

## The three questions

**a. Inputs and outputs.**

Arguments are the input I impose: name = "cap09-web", the ports block,
keep_locally on the image — values that exist because I wrote them.
Attributes are the output the resource exports once alive:
docker_container.web.id, network_data[0].ip_address — values Docker
coined at the container's birth, which no one could know earlier. The
dossier's content was (known after apply) precisely because it
interpolates two such attributes: at plan time the container does not
exist yet, so its outputs cannot exist either — and the unknown
propagates along the reference edge from container to file. What
unlocked it was the apply itself: attributes are born WITH the resource.
The plan staying honest — promising the file while confessing it cannot
say what it will contain — is what makes it reviewable: a plan that
guessed values would be a plan you could not trust.

**b. The blind eye.**

Converging was right by construction: chapters 1 and 2 taught that
reality must match the model, and any hand change is drift to be
absorbed — the plan did exactly its job. What ignore_changes changes is
the contract's scope: for the listed attributes (and only those), diffs
between model and reality stop being drift and become somebody else's
business; the plan looks away by design. After "No changes" reality had
NOT changed: docker inspect still said unless-stopped — the change was
tolerated, not accepted into the model nor reverted. Wisdom: an
autoscaler owns the replica count, a cost system rotates tags — those
knobs legitimately belong to another controller, and fighting them would
be flapping. Patch: silencing a config drift on a port or an image
because "the plan keeps complaining" — that is hiding a divergence that
ought to be fixed in code or in reality. The silent cost: every entry is
a knob the model abdicates forever, invisibly — the file still LOOKS
like it governs restart, but it no longer does.

**c. The meta-arguments and the gallery.**

Three meta-arguments so far: provider (chapter 8) decides WHICH
configured line a resource travels on; depends_on (chapter 4) declares
an edge no reference draws; lifecycle (chapter 3 and today) sets the
tool's own rules — replacement order, safety catches, tolerated knobs.
They speak to the core, not to the provider: nothing of them reaches
Docker's API — they shape how the tool plans, not what the resource is.
In the AWS example, aws_vpc.main.id travels into aws_subnet.app.vpc_id
and then aws_subnet.app.id into aws_instance.web.subnet_id: two edges
that order creation (vpc, subnet, instance) and reverse destruction, with
every id (known after apply) on the first run. In the vSphere example the
data blocks are not resources: they create nothing and instead LOOK UP
what already exists in vCenter — datacenter, datastore, cluster,
network — exporting attributes for the one real resource to consume.
Reading reality instead of writing it: that is exactly chapter 10's
subject.
