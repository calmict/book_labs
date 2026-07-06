# Chapter 9 — Arguments, attributes and the art of turning a blind eye

**Level:** Intermediate
**Estimated time:** 45–55 minutes
**Manual topics:** anatomy of a resource (9.1), arguments and attributes: input and output (9.2), the lifecycle block in detail (9.3), the meta-arguments (9.4), extended example: network and server on AWS (9.5), extended example: a VM on vSphere (9.6), recap (9.7)

## The idea

The resource is the brick everything is made of, and this chapter puts it
on the operating table. The first discovery is that it has two faces: the
*arguments* — what you write, the input — and the *attributes* — what the
resource gives back once born, the output: the id, the IP address Docker
assigned it, the values nobody knew before the apply. You build a dossier
that consumes precisely those outputs, and in the plan you see the trail
they leave: (known after apply), the declared unknown travelling along
the graph.

The second discovery completes chapter 3's lifecycle with its subtlest
piece: ignore_changes. The night team changes a setting of your container
by hand; the plan — faithful to chapters 1 and 2 — wants to converge it
back. But this time the change is *legitimate*: that knob belongs to
another process. You will sign the blind-eye contract, and learn when it
is wisdom and when it is just a patch.

## Goals

By the end you will be able to:

- tell arguments (input) from attributes (output), and say when
  attributes are born;
- read (known after apply) as a value that exists but is not yet
  knowable — and watch it propagate along references;
- use ignore_changes to tolerate a specific drift by contract, and
  explain its risks;
- list the meta-arguments met so far (provider, depends_on, lifecycle)
  and each one's trade;
- read the extended AWS and vSphere examples recognising inputs, outputs
  and edges.

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md.
- Docker running. Free port: 8093.
- Chapters 3 (lifecycle), 4 (graph) and 8 (provider): threads get pulled
  here.

## Your task

### Phase 0 — The resource on the table

Open start/main.tf and look at the container with an anatomist's eyes.
Everything written there — name, image, ports — is *input*: arguments you
impose. But the resource, once alive, exports much more: an id Docker
will coin at birth, an IP address nobody can predict, dozens of computed
values. Those are the *attributes*: the output. You have already used
them without naming them — image = docker_image.web.image_id is an output
of the image entering the container.

### Phase 1 — The dossier (TODO 1)

TODO 1 asks you to write the resource's dossier: a local_file whose
content consumes two outputs of the container —

    container id : ${docker_container.web.id}
    internal ip  : ${docker_container.web.network_data[0].ip_address}

Before applying, look at the plan:

    cd start
    tofu init
    tofu plan

The dossier's content is (known after apply): not an error, not a gap —
it is the *declared* unknown. Those values will be born only with the
resource, and the plan knows it: it promises the file, but confesses it
cannot tell you what it will contain. Note that the unknown travels: born
in the container, it propagates via reference down to the dossier (it is
chapter 4's edge, carrying values). Now:

    tofu apply
    cat dossier.txt
    tofu output

Real id and IP, discovered at birth and put to work immediately.

### Phase 2 — The night team

It is 03:12 (again). An operator changes your container's restart policy,
by hand:

    docker update --restart unless-stopped cap09-web
    tofu plan

The plan sees it: ~ restart "unless-stopped" -> "no", update in-place. It
is the conditioned reflex of chapters 1 and 2: reality deviates from the
model, the plan proposes to converge it back. So far, nothing new —
except one detail: *this time the operator was right*. That policy is
governed by the operations team, not by your model. If you applied, you
would cancel a legitimate choice; if you updated the model at every
change of theirs, you would be another team's secretary.

### Phase 3 — The blind-eye contract (TODO 2)

TODO 2 adds to the container the missing piece of lifecycle:

    lifecycle {
      ignore_changes = [restart]
    }

Re-read the plan:

    tofu plan
    docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' cap09-web

No changes — and the inspect confirms reality stayed unless-stopped. The
drift has not disappeared: it has been *tolerated by contract*, on that
knob and that knob only. It is the right tool when an attribute
legitimately belongs to another process (an autoscaler adjusting
replicas, a system rotating tags); it is a dangerous patch when you use
it to hide drift that ought to be governed — every entry in
ignore_changes is a knob your model abdicates, forever and silently.

### Phase 4 — The meta-arguments recap

Look at the complete main.tf again: without noticing you have already
collected 9.4's meta-arguments — provider (chapter 8: placement),
depends_on (chapter 4: the hand-declared edge), lifecycle (chapter 3 and
today: replacement and tolerance rules). They are arguments that speak
*to the tool* rather than to the provider: none of them ends up in
Docker's API. Missing from the roll call: count and for_each — chapter
15, and you will see they deserve a whole chapter.

### Phase 5 — The gallery of real sites (read)

In start/examples/ you will find the manual's two extended examples, to
be read with today's glasses:

- **aws-network-server.tf.example** — the network→server chain: the VPC
  exports an id that enters the subnet, the subnet the server; three
  resources, two edges, and the unknown crossing the whole graph at the
  first apply.
- **vsphere-vm.tf.example** — the on-premise VM: and here you will
  notice blocks that are *not* resources — they create nothing, they
  *query* what exists (the datastore, the vCenter network). They are
  chapter 10's scouts.

### Cleanup

    tofu destroy

## Definition of done

- In Phase 1's plan the dossier's content was (known after apply); after
  the apply dossier.txt contains real id and IP.
- Phase 2's plan showed ~ restart "unless-stopped" -> "no".
- After TODO 2: plan answers No changes AND docker inspect still shows
  unless-stopped (the drift is there, the contract tolerates it).
- You can point at three arguments and three attributes in your main.tf.
- You answered the three questions in answers.md.

## The three questions

**a.** Inputs and outputs: define argument and attribute using *your own*
examples from main.tf. Why was the dossier's content (known after apply)
and what unlocked it? What does that tell you about the moment attributes
are born — and about why the plan stays honest instead of inventing
values?

**b.** The blind eye: why was Phase 2's behaviour (converging back)
*right* according to chapters 1 and 2, and what exactly does the
ignore_changes contract change? After the "No changes" plan, had reality
changed or not? Give one example where ignore_changes is wisdom and one
where it is a patch — and explain the silent cost of every entry in that
list.

**c.** The meta-arguments and the gallery: list the three meta-arguments
you have already used and each one's trade (and whom they speak to, if
not the provider). Then in the AWS example: spot an attribute travelling
from one resource to another and describe the edge it draws. Finally in
the vSphere one: what is NOT a resource, what does it do instead of
creating, and why is it the perfect announcement of chapter 10?
