# Chapter 16 — Answers (model solution)

## The bench (Phase 0)

    lower(trimspace("  Web-01 "))  ->  "web-01"
    split("-", "web-01")[0]        ->  "web"

## The assembly line (Phase 1)

    docker_container.host["api-02"]
    docker_container.host["db-03"]
    docker_container.host["web-01"]
    # 4 raw hosts in, 3 containers out (Web-01 / web-01 deduped)

## The derived map and the filter (Phases 2-3)

    host_roles = { "api-02" = "api", "db-03" = "db", "web-01" = "web" }
    web_hosts  = toset(["web-01"])

## The three questions

**a. The bench.**

An HCL function takes input in parentheses and returns a value — and that is
all: it is pure, with no side effects. It reads nothing about your real
infrastructure, writes nothing, touches no state; lower("API-02") is just
"api-02", the same answer every time, everywhere. That purity is exactly why
tofu console is safe even against a production project: the console evaluates
expressions in memory, so typing lower(...) or [for ...] can create, change or
destroy nothing — the worst you can do is read a value. Three functions I tried:
trimspace (string family — strips surrounding whitespace), merge (collection
family — combines two maps), jsonencode (encoding family — serialises a value to
a JSON string). Others in play: split (string), toset/tolist (type conversion),
length (collection), sort (collection).

**b. The assembly line.**

A list comprehension [for h in coll : expr] walks a collection and returns a
*list* of the expression's results — one element per input. A map comprehension
{ for h in coll : key => value } (note the braces and the =>) returns a *map*
instead, pairing a computed key with a computed value: I used it to turn the set
of hosts into host -> role. A trailing if — [for h in coll : expr if cond] —
*filters*: only elements where cond is true reach the output, which is how
web_hosts kept just the web tier. toset()'s role is separate from the for: the
for expression alone produced a *list* with web-01 appearing twice (from
"  Web-01 " and "web-01", both normalised to "web-01"). toset() converts that
list to a set, and a set has no duplicates and no order — so the two collapse
into one identity. That is why 4 raw hosts produced 3 containers: the for
cleaned all four to lowercase-trimmed strings, and the toset merged the two
identical web-01 into a single key that for_each then built once.

**c. Try first, fit later.**

Trying an expression in console first is faster and safer than writing it and
running apply to see. The tightest loop with apply is: edit the file, init if
needed, plan, read the plan, maybe apply, maybe destroy to reset — seconds to
minutes, and if the expression is wrong you either get a plan error or, worse,
build the wrong thing. Console is a single keystroke away from an answer, with
no file to edit and nothing to undo. The link to chapter 6's cycle: plan
compares your *whole* configuration against state and reality to compute a set
of actions — it answers "what would change". Console answers a smaller, purer
question — "what does *this expression* evaluate to" — with no state, no
provider round-trips, no actions. The bench saves you the whole plan/apply
round-trip for the part of the work that is just shaping values; you reach for a
plan only once the values are already known to be right.
