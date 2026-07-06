# Chapter 10 — Answers (model solution)

## Read during the plan (Phase 1)

    data.docker_network.platform: Reading...
    data.docker_network.platform: Read complete after 1s [id=2d7f...]

    network id : 2d7f5fdc02461d63488e26df1b5713f69e822ab02b255248fce9c5104f375584
    driver     : bridge
    scope      : local
    # (real values, IN THE PLAN — nothing to wait for)

## Building on someone else's ground (Phase 2)

    cap10-platform-net: 172.28.0.2

## The two fates (Phase 3)

    # netcard:   content fully resolved (the network exists, independent
    #            of this run -> read at plan)
    # freshcard: content = (known after apply) (its data reads a network
    #            born in this run -> read deferred to apply)

## Reading is not owning (Phase 4)

    data.docker_network.fresh
    data.docker_network.platform

    # after the destroy: YES, cap10-platform-net is still there

## The three questions

**a. Reading vs owning.**

A resource imposes: docker_container.web describes something that must
exist, and the tool creates, converges and eventually destroys it. A data
queries: data.docker_network.platform describes something to FIND — it
created nothing, it exported the attributes of an object someone else
owns. Both appeared in state list, the data entries with their data.
prefix: the tool records what it read alongside what it manages. At
destroy the difference became physical: the five owned resources were
demolished, the data entries simply vanished from the state — and the
platform's network, the object they described, was not touched. Reading
gives you values, not responsibility.

**b. Rule 10.5 in one plan.**

The netcard was resolved because its data source's configuration was
fully known before the run and the object existed: the tool could read it
DURING the plan, so every downstream value was real. The freshcard's data
had an argument fed by a resource of this same run (docker_network.ours),
which did not exist yet: the read had to be deferred to apply, and
everything downstream degraded to (known after apply). General rule: a
data source is read at plan time when its arguments are known and nothing
it depends on is being created in this run; otherwise the read slips to
apply. It matters for review because a plan full of resolved values is a
plan you can genuinely evaluate, while every deferred read widens the
blind spot: you are approving actions whose inputs nobody has seen yet —
sometimes unavoidable, always worth noticing.

**c. The bridge to chapter 11.**

It remembers in the state: the values every data block read are stored
there next to the resources, which is why state list shows them. If the
platform team changed their network, the next plan would re-read the
data source (reads happen at every plan) and the fresh values would flow
into whatever consumes them — possibly proposing changes to MY resources
even though MY code never changed. Three things can now disagree: what
the code declares, what the state remembers, what reality actually is —
and sorting out who wins is exactly chapter 11's subject.
