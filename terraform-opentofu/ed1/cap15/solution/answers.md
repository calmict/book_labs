# Chapter 15 — Answers (model solution)

## The fragile index (Phase 1)

    # docker_container.web[1] must be replaced
    ~ name = "cap15-bravo" -> "cap15-charlie" # forces replacement
    # docker_container.web[2] will be destroyed

## Counting by name (Phase 2)

    # docker_container.web["bravo"] will be destroyed
    Plan: 0 to add, 0 to change, 1 to destroy.
    # (alpha and charlie untouched)

## The conditional and the dynamic block (Phases 3-4)

    # canary_enabled=true:
    # docker_container.canary[0] will be created  ->  Plan: 1 to add
    # docker inspect cap15-alpha labels:
    "team":"platform"  "tier":"web"

## The three questions

**a. The trap.**

count multiplies by position: each copy's identity IS its index. The state
holds docker_container.web[0], [1], [2], each bound to a slot. When I removed
bravo from the list, the list closed up — index 1 stopped meaning bravo and
started meaning charlie, index 2 stopped existing. Terraform compares by
address, not by value: so [1] is "the same resource" whose name changed from
cap15-bravo to cap15-charlie, and name is a ForceNew attribute (chapter 3), so
it must be replaced; [2] has no counterpart in the new plan, so it is destroyed.
alpha survived only because it sits at index 0, before the gap, where the
renumbering does not reach. Nothing about the containers themselves changed —
the churn is an artefact of tying identity to position.

**b. List vs set.**

for_each keys each instance by an identity, and identities must be a *set* of
distinct, unordered keys (a set of strings, or a map's keys) — never a list. A
list has exactly the thing a for_each must not depend on: order, i.e.
positions. If for_each accepted a list it would smuggle back the fragile index —
reordering or removing a middle element would shift keys and churn the tail,
the very trap we are escaping. toset() throws the order away and keeps only
membership: ["alpha","bravo","charlie"] becomes the set {alpha, bravo,
charlie}, and each element becomes its own stable key. After the conversion the
state holds web["alpha"], web["bravo"], web["charlie"]; removing bravo removes
exactly the key "bravo" and leaves the other two keys — and therefore the other
two resources — untouched. Identity is now the name, and a name does not depend
on its neighbours.

**c. The two multiplications.**

count and for_each multiply *resources*: they produce N separate objects in the
state, each with its own address (web[0] or web["alpha"]). A dynamic block
multiplies *nested blocks* inside a single resource: it does not create more
containers, it generates repeated sub-blocks (here, one labels block per map
entry) within one container. Example of each: for_each for three containers with
distinct names; a dynamic block for the variable number of ports or labels a
single container needs. On the conditional: count = var.enabled ? 1 : 0 makes a
resource optional *within the code* — count = 0 declares it but creates zero
instances, so toggling the variable adds or destroys it cleanly, and the
resource stays in version control, reviewable and documented. Commenting it out
instead removes it from the language entirely: no plan can reason about it, the
toggle is a manual edit, and the intent ("this is optional, off by default")
disappears from the file. The conditional keeps the switch *in* the
configuration; a comment takes it out of it.
