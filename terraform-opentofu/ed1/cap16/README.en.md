# Chapter 16 — The workbench

**Level:** Intermediate
**Estimated time:** 45–55 minutes
**Manual topics:** what a function is in HCL (16.1), the families of functions (16.2), examples you will actually meet (16.3), for expressions: transforming collections (16.4), terraform console: the workbench (16.5)

## The idea

The last chapter closed with a promise: the collections you hand to count and
for_each often have to be *prepared* first — cleaned, transformed, filtered.
This chapter gives you the tools to prepare them, and a bench to test the tools
before you fit them.

The tools are the **functions**: HCL has about a hundred, ready-made (you cannot
write your own in the classic way — you take what is there). They transform a
string (lower, trimspace, split), count and combine collections (length, merge,
keys), convert them (toset, tolist, jsonencode). A function takes input in
parentheses and returns a value: nothing else, no side effects.

The bench is **tofu console**: a REPL where you type an expression and see the
result at once, *without touching anything* — no plan, no apply, no state. It is
where you try lower(trimspace(" Web-01 ")) and read "web-01" before you trust it
into the code.

And the assembly line is the **for expression**: not chapter 15's meta-argument,
but an expression that takes a collection and spits out another, transformed one.
[for h in list : clean(h)] remakes the list cleaned; { for h in list : h =>
role(h) } builds a map from it; and a trailing if *filters*. You will start from
a badly written list of hosts — whitespace, random capitals, a duplicate — and
turn it into the clean, ordered set that then really drives your containers.

## Goals

By the end you will be able to:

- say what an HCL function is and recognise the main families (string,
  collection, conversion, encoding);
- use tofu console to try an expression without touching state or
  infrastructure;
- transform a list with a for expression (list comprehension) and clean it with
  functions;
- build a *map* with a for expression (map comprehension), and *filter* it with
  an if;
- connect the transformed collection to a for_each (chapter 15's legacy) and see
  the dedup at work.

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md.
- Docker running. No host ports published.
- Chapter 15 (for_each, toset): here you prepare the collections you feed it.

## Your task

### Phase 0 — The bench (tofu console)

Before writing anything, get on the bench. From start/:

    cd start
    tofu init
    tofu console

You are in the REPL. Try the tools — each line returns a value, nothing is
touched:

    lower(trimspace("  Web-01 "))
    length(["a", "b", "c"])
    merge({ team = "web" }, { tier = "1" })
    split("-", "web-01")
    split("-", "web-01")[0]

Read the answers: "web-01", 3, the merged map, the list ["web","01"], "web".
These are the families you will use: string (lower, trimspace, split),
collection (length, merge), access ([0]). Leave the bench with exit (or Ctrl-D).
The chapter's golden rule: **any expression whose behaviour you are unsure of,
try it here before you put it in the code.**

### Phase 1 — The assembly line (TODO 1: list comprehension)

Open start/main.tf: the raw_hosts variable is a *badly* written list —
"  Web-01 ", "API-02", "web-01", "DB-03 ": whitespace on the sides, inconsistent
capitals, and Web-01/web-01 which are the same host written two ways. TODO 1
asks you to clean it with a for expression. First **try it on the bench**:

    tofu console
    [for h in var.raw_hosts : lower(trimspace(h))]

You see the normalised list — but with web-01 *twice*. Wrap it in toset() to
dedup and get identities:

    toset([for h in var.raw_hosts : lower(trimspace(h))])

Leave, and write the result into the clean_hosts local (replacing the toset([])
placeholder):

    clean_hosts = toset([for h in var.raw_hosts : lower(trimspace(h))])

This local already drives a for_each of containers (at the bottom of the file,
chapter 15's legacy). Apply:

    tofu apply
    tofu state list

Four raw hosts, but **three** containers: docker_container.host["api-02"],
["db-03"], ["web-01"]. The duplicate vanished in the toset. The collection you
prepared by hand became infrastructure.

### Phase 2 — The derived map (TODO 2: map comprehension)

A for expression can build a *map*, not just a list: change the syntax from : to
=>. TODO 2 builds host_roles, mapping each host to its *role* — the prefix
before the dash. Try it:

    tofu console
    { for h in local.clean_hosts : h => split("-", h)[0] }

Read { "api-02" = "api", "db-03" = "db", "web-01" = "web" }. Write it into the
host_roles local (replacing {}), then look at it as an output:

    tofu apply
    tofu output host_roles

### Phase 3 — The filter (TODO 3: comprehension with if)

A trailing if on the for expression *filters*: it keeps only the elements that
pass the condition. TODO 3 builds web_hosts, only the hosts whose role is "web".
Try it:

    tofu console
    toset([for h in local.clean_hosts : h if split("-", h)[0] == "web"])

Read toset(["web-01"]): only it passes. Write it into the web_hosts local
(replacing toset([])), then:

    tofu apply
    tofu output web_hosts

### Phase 4 — The functions that produce a file

Look at the bottom of the file at the local_file inventory (already written, not
a TODO): its content is jsonencode of a structure using sort, tolist and your
three collections. It is the other face of functions — not only tried on the
bench, but producing a real artifact:

    cat inventory.json

An ordered JSON with hosts, roles and web: your transformations, serialised.
jsonencode/sort/tolist are the *encoding* and *conversion* families at work.

### Phase 5 — The bridge (reflect)

You took raw material and worked it on the bench until it became infrastructure:
functions to clean, for expressions to reshape, console to try without risk. So
far, though, you have *repeated* the same pattern (variables, resources,
outputs) in every folder. Part 5 packages it once and for all: chapter 17,
modules, takes this block and makes it reusable with a name and some doors — the
variables and outputs you already know, but as the *interface* of a box.

### Cleanup

    tofu destroy

## Definition of done

- On the bench (console): lower(trimspace("  Web-01 ")) gave "web-01" and
  split("-", "web-01")[0] gave "web".
- After TODO 1, 4 raw hosts became 3 containers (dedup in the toset): the
  addresses were host["api-02"], ["db-03"], ["web-01"].
- host_roles (TODO 2) mapped web-01=web, api-02=api, db-03=db.
- web_hosts (TODO 3) held only web-01.
- inventory.json held the JSON with hosts, roles and web.
- You answered the three questions in answers.md.

## The three questions

**a.** The bench: what is an HCL function (input, output, side effects) and why
is tofu console safe to use even on a real project in production? Name three
functions you tried and each one's family.

**b.** The assembly line: explain the difference between the for expression as a
*list comprehension* ([… : …]) and as a *map comprehension* ({… : … => …}), and
what the trailing if does. In TODO 1, what exactly is toset()'s role compared to
the for expression alone — and why did 4 raw hosts produce 3 containers?

**c.** Try first, fit later: why is it worth trying an expression in console
*before* writing it into the code, instead of writing it and running apply to
see if it works? Connect the answer to chapter 6's plan/apply cycle — what does
the bench save you, and how is it different from a plan?
