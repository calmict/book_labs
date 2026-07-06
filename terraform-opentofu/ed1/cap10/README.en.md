# Chapter 10 — The land registry

**Level:** Intermediate
**Estimated time:** 40–50 minutes
**Manual topics:** what a data source is (10.1), why they are fundamental (10.2), reading existing resources not managed by Terraform (10.3), a small gallery of common data sources (10.4), known at plan or known only at apply? (10.5), recap and bridge towards State (10.6)

## The idea

No construction site starts on virgin ground: there is the neighbourhood's
network, the waterworks, the land registry recording what exists. So far
everything in your model was created by you; in this chapter you learn to
*consult* — to read what exists, belongs to others, and is not yours to
manage.

The platform team created a Docker network (by hand: Phase 0, you play
them). You read it with a data block — the scouts announced in chapter 9's
gallery — and lean your container on it: you build *on* what you do not
own. Along the way you discover chapter 9's reverse: a data source's
attributes are known *already at plan* — the existing is consulted right
away, there is nothing to wait for — except when the data depends on a
resource yet to be born: then the read slips to the apply, and the unknown
returns. You will see the two cases side by side, in the same plan. And at
destroy, the proof that closes the chapter: what you read is not yours —
the platform's network survives intact.

## Goals

By the end you will be able to:

- write a data block and explain how it differs from a resource (reading
  vs owning);
- build your own resources on top of other people's objects, without
  managing them;
- predict when a data source is read at plan and when it slips to apply —
  and recognise both cases in the plan;
- say what appears in state list with the data. prefix and what happens to
  it at destroy;
- name a few classic data sources of the real worlds (the gallery).

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md.
- Docker running. No port needed this time.
- Chapters 9 (attributes, known after apply) and 4 (edges): they get
  flipped here.

## Your task

### Phase 0 — The world that already exists

Put on the platform team's helmet and create their network, by hand:

    docker network create --subnet 172.28.0.0/16 cap10-platform-net

From this moment on you are back in your own shoes: that network exists,
has an owner, and *it is not you*. Your model must never create it, nor
modify it, nor destroy it — only use it.

### Phase 1 — Consulting the registry (TODO 1)

TODO 1 asks you for the first data block of your career:

    data "docker_network" "platform" {
      name = "cap10-platform-net"
    }

Same grammar as a resource — type, label, body — but the opposite trade:
a resource *imposes* (creates what it describes), a data *queries* (finds
what you describe and exports its attributes). Together with the data,
uncomment its registry card (netcard): a local_file consuming its id,
driver and scope. Now the important move — look at the plan *before*
applying:

    cd start
    tofu init
    tofu plan

Two things to note, both against chapter 9's grain. First: at the top of
the plan, data.docker_network.platform: Reading... and Read complete —
the read happened *during the plan*. Second: the netcard's content is
*already resolved* — real id, real driver, no (known after apply). The
existing has nothing to wait for: you consult it, and the values are
there.

### Phase 2 — Building on someone else's ground (TODO 2)

TODO 2 attaches your container to the platform's network:

    networks_advanced {
      name = data.docker_network.platform.name
    }

Apply and verify:

    tofu apply
    docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}: {{$v.IPAddress}}{{end}}' cap10-web
    cat netcard.txt

Your container lives in their network (IP in 172.28.x): you built on top
of an object you do not manage, and this time the graph's edge starts
from a data — the ordering still holds (first read, then build).

### Phase 3 — The unknown returns (the deferred case)

At the bottom of main.tf you will find block B of the experiment already
written: a network of *yours* (docker_network "ours") and a second data
reading it — but that network will be born only at apply. Ask for the
plan and compare the two cards:

    tofu plan

The netcard (Phase 1) is resolved; the freshcard is (known after apply).
Same data type, two fates: if what the data describes exists and is
independent of this run, the read happens at plan; if it depends on a
resource yet to be born, it slips to apply — and chapter 9's declared
unknown reappears downstream. It is rule 10.5 in a single plan.

    tofu apply
    cat freshcard.txt

### Phase 4 — Reading is not owning

    tofu state list

The data. entries are on the list: the tool *remembers* what it read
(where does it remember it? in the state — and that is the bridge to
chapter 11). But now the queen of proofs:

    tofu destroy
    docker network ls

Your container, your network, the cards: gone. The platform's network:
*intact*. The destroy demolishes what you own, never what you consult —
the registry does not burn when you demolish the house.

### Phase 5 — The small gallery (read)

The data sources you will meet first in the real worlds: aws_ami with
most_recent = true (the latest image matching the filters — the absolute
classic), aws_availability_zones and aws_caller_identity (who am I, where
can I build), and the four vsphere_* you already read in chapter 9's
gallery — which you can now name: they were data sources, and now you
know exactly what they do and when they are read.

### Cleanup

The platform's network you created by hand, playing another team — and by
hand it goes away:

    docker network rm cap10-platform-net

## Definition of done

- In Phase 1's plan: Read complete during the plan, and the netcard's
  content already resolved (no known after apply).
- The container is attached to cap10-platform-net with an IP in 172.28.x.
- In the same Phase 3 plan: netcard resolved AND freshcard (known after
  apply) — you can explain the difference.
- After the destroy: your 5 resources gone, cap10-platform-net still in
  docker network ls.
- You answered the three questions in answers.md.

## The three questions

**a.** Reading vs owning: same grammar, opposite trade — define the
difference between resource and data with this exercise's examples. What
appeared in state list with the data. prefix, and what happened to those
entries (and to the objects they describe) at destroy?

**b.** Rule 10.5 in one plan: why was the netcard resolved at plan and
the freshcard not? State the general rule (when a data is read at plan,
when it slips to apply) and explain why the difference matters when you
*review* a plan before approving it.

**c.** The bridge: the tool "remembers" what the data blocks read —
where? And if the platform team changed their network between one plan
and the next, what would you expect the next plan to do with that data?
(No perfect answer needed: it is the opening of chapter 11 — the three
sources of truth.)
