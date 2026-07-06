# Chapter 3 — Answers (model solution)

## The renovation (Phase 1)

    # container ID before the apply:  437e...(a long sha256 — yours differs)
    # container ID after the apply:   437e...(the SAME sha256)
    # the plan title line:            docker_container.web will be updated in-place

## The reconstruction (Phase 2)

    ~ image = "sha256:5164..." # forces replacement -> (known after apply) # forces replacement
    ~ name  = "cap03-web-1-25-alpine" -> "cap03-web-1-26-alpine" # forces replacement

    -/+ destroy and then create replacement

## The flipped order (Phase 3)

    +/- create replacement and then destroy

## The safety catch (Phase 4)

    Error: Instance cannot be destroyed
    Error: Instance cannot be destroyed

    (the second one on a mere version bump: a replace is a destroy + create)

## The three questions

**a. Which attribute travelled in-place and which forced the replacement?
How did you know before applying, and why does the provider decide?**

Memory travelled in-place: the plan titled the change "will be updated
in-place" and marked the attribute with a tilde (~). The image version
forced a replacement: the title said "must be replaced", the resource
carried -/+, and every attribute that cannot change on a living object was
marked "# forces replacement". I knew before applying because the plan IS
the announcement — reading it is the whole point. The provider decides
because the split is not a matter of taste but of what the real world's API
can absorb: Docker can change the memory limit of a running container
(docker update exists), but no API can swap the image under a running
container — the only way is to stop and re-create it. That knowledge —
which changes pass through the object and which replace it — is encoded,
attribute by attribute, in the provider's schema.

**b. What made create_before_destroy possible here, and what would a fixed
name have caused? What does prevent_destroy block — and not block?**

It worked because the container's name embeds the version: the new
generation (cap03-web-1-27-alpine) and the old one (cap03-web-1-26-alpine)
never contend a shared identity, so they can be alive together during the
overlap. With a fixed name the create step would have failed — the name
already taken — which is the general rule: create_before_destroy requires
that no unique piece of identity (a name, an address, a port binding) be
contended between generations. prevent_destroy blocks every plan that would
destroy the instance — the explicit tofu destroy, and, surprisingly, any
attribute change that forces a replacement, because a replace is a destroy
plus a create. What it does NOT block: anything outside the model — a
docker rm by hand at 03:12 (that is chapter 1's drift world, and the catch
lives in the plan, not in reality), and of course an operator who removes
the flag from the code first. It is a seatbelt, not a vault.

**c. Why does rebuilding reduce risk compared to renovating, and what is
still missing from the picture?**

A renovated object accumulates history: every in-place change is one more
layer on the snowflake, and the object's current state is the sum of all of
them — often unreproducible, exactly like chapter 1's hand-made servers.
An upgrade done by renovation is asymmetric: going forward is scripted,
going BACK often is not (downgrade paths are rarely tested). Rebuilding
makes change symmetric and boring: the new object comes wholly from the new
mould, so rolling back is just re-applying the previous version — another
replacement, same gesture, same confidence. Risk shrinks because every
state the object can be in is one the code can produce from scratch. What
is still missing: here the tool built the image before the container and
destroyed them in the reverse order — with two resources it looks obvious,
but who computes that order when there are fifty, and what happens if the
dependencies form a loop? That is the dependency graph: chapter 4.
