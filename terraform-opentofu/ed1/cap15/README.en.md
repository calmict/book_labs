# Chapter 15 — The fleet: by number or by name

**Level:** Intermediate
**Estimated time:** 50–60 minutes
**Manual topics:** count: multiply by number (15.1), count's trap: the fragile index (15.2), for_each: multiply by identity — list vs set (15.3), conditionals: to exist or not to exist (15.4), dynamic blocks: generating nested blocks (15.5)

## The idea

So far every resource was a one-off, written by hand. But a neighbourhood has a
hundred identical houses, and nobody writes them one by one. This chapter gives
you the two ways to *multiply* a resource — and shows you why the choice between
them is one of the most important you will make.

The first way counts **by number**: count. You give a number, and get that many
copies, indexed [0], [1], [2]. Handy, immediate — and with a hidden trap. Each
copy's identity is its *position*: house number 2. Remove a house in the middle
of the row, and every house after it *shifts down a number*: 3 becomes 2, 4
becomes 3. Terraform, which ties identity to position, thinks you renamed half
the fleet — and rebuilds it. You will see it in your own plan: a single removal,
and the fire spreads down the tail.

The second way counts **by name**: for_each. Each copy has a *stable* identity —
not its position, but a key: ["alpha"], ["bravo"], ["charlie"]. Remove the one
in the middle, and only it disappears: the others do not even notice. It is the
cure for the trap, and the reason for_each is almost always the right choice.

Close with two supporting tools: the **conditional**
(count = var.enabled ? 1 : 0 — a resource that exists or does not), and the
**dynamic** block, which generates nested blocks from a collection — the same
multiplication, but *inside* a resource.

## Goals

By the end you will be able to:

- multiply a resource with count and read its indexed addresses ([0], [1]…);
- explain and *demonstrate* the fragile-index trap: why removing a middle
  element triggers a cascade of replacements;
- multiply by identity with for_each, and say why it wants a set or a map (not a
  list) — hence toset();
- make a resource exist or vanish with a conditional (? 1 : 0);
- generate nested blocks with a dynamic block from a collection.

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md.
- Docker running. No host ports published: no conflicts.
- Chapters 3 (replace) and 14 (variables, locals): you see them multiplied here.

## Your task

### Phase 0 — The fleet counted by number (count)

In start/ the fleet is born *counted by number*: the fleet variable is a list
(alpha, bravo, charlie) and the container uses count = length(var.fleet), with
name cap15-${var.fleet[count.index]}. Apply:

    cd start
    tofu init
    tofu apply
    tofu state list

Look at the addresses: docker_container.web[0], [1], [2]. Each one's identity is
its *number*.

### Phase 1 — The fragile-index trap

Now remove the house *in the middle* — bravo — by passing the list without it,
and ask for the plan (do not apply):

    tofu plan -var 'fleet=["alpha","charlie"]'

Read the fire:

    # docker_container.web[1] must be replaced
    ~ name = "cap15-bravo" -> "cap15-charlie" # forces replacement
    # docker_container.web[2] will be destroyed

A single removal, two resources upended. Why? count ties identity to
*position*: index 1 was bravo, now it is charlie, so to Terraform resource [1]
must be renamed (and the name forces the replace, chapter 3's echo); index 2 no
longer exists, destroyed. Only alpha ([0]) survives, because it sits before the
gap. This is the trap: **with count, deleting in the middle churns the tail.**

### Phase 2 — Counting by name (TODO 1: for_each)

TODO 1 asks you to re-count the fleet *by identity*. Rewrite the web resource,
replacing count with for_each:

    resource "docker_container" "web" {
      for_each = toset(var.fleet)
      name     = "cap15-${each.key}"
      image    = docker_image.web.image_id
    }

Two details. First: for_each does not accept a *list*, it wants a *set* or a
*map* — because a list has an order (positions), a set does not (only
membership). toset() turns the list into a set of identities. Second: inside the
resource there is no more count.index, but each.key — the key, that is, the
name. Re-apply and look at the addresses:

    tofu apply
    tofu state list

Now they are docker_container.web["alpha"], web["bravo"], web["charlie"]:
indexed by *name*. Redo Phase 1's experiment:

    tofu plan -var 'fleet=["alpha","charlie"]'

This time: Plan: 0 to add, 0 to change, 1 to destroy — and the only one touched
is web["bravo"]. alpha and charlie do not move: their identity does not depend
on who sits next to them. The trap is gone.

### Phase 3 — To exist or not to exist (TODO 2: the conditional)

TODO 2 adds a *canary* — a container that exists only when you switch it on.
Complete count with a conditional expression:

    resource "docker_container" "canary" {
      count = var.canary_enabled ? 1 : 0
      name  = "cap15-canary"
      image = docker_image.web.image_id
    }

count = 0 means *no* copies: the resource is declared but does not exist. It is
the idiomatic way to make a resource optional. Try it:

    tofu plan                          # canary_enabled=false: no canary
    tofu plan -var canary_enabled=true # 1 to add: it appears

The ? 1 : 0 switch is the pattern you will meet everywhere to turn pieces of
infrastructure on and off.

### Phase 4 — Generating nested blocks (TODO 3: dynamic)

So far you have multiplied *resources*. The dynamic block multiplies *blocks
inside* a resource. TODO 3 generates a labels block for each entry in the
var.labels map, inside the web container:

    dynamic "labels" {
      for_each = var.labels
      content {
        label = labels.key
        value = labels.value
      }
    }

The name after dynamic ("labels") is the block to generate; inside content you
describe *one* iteration, and labels.key/labels.value draw from the map. Apply
and check the labels really landed:

    tofu apply
    docker inspect -f '{{json .Config.Labels}}' cap15-alpha

You will see team:platform and tier:web. Change var.labels, and the blocks
regenerate by themselves: it is the end of nested blocks copy-pasted by hand.

### Phase 5 — The bridge (reflect)

count counts by number (fragile), for_each by name (stable), the conditional
switches on and off, dynamic multiplies blocks. They all take a *collection* and
turn it into resources or blocks — but collections often have to be *prepared*
first (filter, transform, merge): that is exactly chapter 16, the functions and
the for expressions.

### Cleanup

    tofu destroy

## Definition of done

- With count, the addresses were web[0], [1], [2]; removing bravo produced a
  replace + a destroy (the cascade).
- After TODO 1, the addresses were web["alpha"] etc.; removing bravo touched
  *only* bravo (0 add, 0 change, 1 destroy).
- With TODO 2, canary_enabled=true produced 1 to add; false, no canary.
- After TODO 3, docker inspect on cap15-alpha showed the team and tier labels.
- You answered the three questions in answers.md.

## The three questions

**a.** The trap: explain in your own words why, with count, removing bravo
*replaced* charlie and *destroyed* the last one, while alpha survived. What ties
count to each copy's identity, and why did the changing name force a replace
(which chapter)?

**b.** List vs set: why does for_each not accept a list but want a set or a map?
What does a list have that a for_each must not have, and what exactly does
toset() do? After the conversion, why does removing bravo no longer touch alpha
and charlie?

**c.** The two multiplications: tell count/for_each apart (they multiply
*resources*) from the dynamic block (it multiplies *blocks* inside a resource) —
with your own example of when each is needed. And the conditional ? 1 : 0: why
is count = 0 the idiomatic way to make a resource optional, instead of
commenting it out?
