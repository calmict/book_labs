# Chapter 12 — One notebook, with a lock

**Level:** Intermediate
**Estimated time:** 45–55 minutes
**Manual topics:** backends: the answer to the question «where» (12.1), configuring a backend: init and state migration (12.2), the most common remote backends (12.3), the lock: state locking (12.4), recap and bridge (12.5)

## The idea

Chapter 11 closed on an incident: two colleagues, two notebooks, one
contested reality. The solution has a name — backend — and it is the
answer to the question "where does the state live?". In this exercise you
build the answer: the platform team (you again, helmet on) switches on
the site's noticeboard — a Consul in a container, a real remote backend —
and you *move* your notebook in there with the official manoeuvre: the
backend block plus init -migrate-state. You will verify in person that
the local file emptied and that the state now lives in the backend (with,
still in plain text, what you know from chapter 11 inside: the house
changed, the custody rules did not).

Then the colleague returns — and this time the story is different: he
attaches to the same backend and his first plan says No changes: *he sees
your resources*, because he reads your very memory. And the grand finale:
while one of your applies is running, he tries to work — and the lock
stops him, with a full name tag: Error acquiring the state lock, stating
who holds it and for which operation. Chapter 11's chaos has become an
orderly queue.

## Goals

By the end you will be able to:

- explain what the backend block governs (where the state lives, who can
  read it, how writes are serialised);
- migrate a local state into a remote backend with init -migrate-state,
  and verify the outcome from both sides;
- attach a second collaborator to the same state and demonstrate that
  chapter 11's incident can no longer happen;
- read the lock error (ID, path, operation, who) and know that
  force-unlock exists as break-glass;
- find your way among the common backends (s3, azurerm, gcs, consul, pg,
  http).

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md.
- Docker running (for the Consul noticeboard). Free port: 8500.
- Chapter 11: this exercise is its second act.

## Your task

### Phase 0 — The site's noticeboard

Helmet on, switch on the service that will host the shared notebook:

    docker run -d --name cap12-consul -p 127.0.0.1:8500:8500 \
      hashicorp/consul:1.20 agent -dev -client=0.0.0.0

(Dev mode, plaintext, on localhost: lab-grade — in production this
noticeboard would have TLS, ACLs and replicas.) Then, back in your own
shoes, a small world with *local* state:

    cd start
    tofu init
    tofu apply
    ls -la terraform.tfstate

The notebook is there, next to the code, as always. For the last time.

### Phase 1 — The move (TODO 1)

TODO 1 adds to the terraform block the answer to the question «where»:

    backend "consul" {
      address = "127.0.0.1:8500"
      scheme  = "http"
      path    = "book-labs/cap12"
    }

Note what it does NOT say: nothing about resources, nothing about the
provider. The backend is pure state logistics. Now the official
manoeuvre:

    tofu init -migrate-state

Answer yes to the copy question, then verify the move, from both sides:

    tofu state list
    ls -la terraform.tfstate*
    curl -s http://127.0.0.1:8500/v1/kv/book-labs/cap12 | head -c 300

state list works as before (the resource is there) — but the local file
is down to zero bytes (with a courtesy .backup), and in Consul's KV there
is a base64 Value starting with eyJ2ZXJzaW9uIjo0: it is your state,
version 4, moved bag and baggage. Custody included: whoever can read that
key also reads chapter 11's secrets — changing house does not change the
rules (restricted access, encryption: and remember OpenTofu's ace,
chapter 20).

### Phase 2 — The colleague, second act

Replay chapter 11's scene, with the variation that changes everything:
the colleague clones code *that now contains the backend block*.

    mkdir ../colleague
    cp main.tf ../colleague/
    cd ../colleague
    tofu init
    tofu state list
    tofu plan

No migration this time (his local state is empty: he merely *attaches*),
and read the result: state list lists YOUR resources, and the plan says
No changes. Same code, same memory, same reality: the three sources are a
single chain again, for whoever clones the project.

### Phase 3 — The lock (TODO 2)

One last danger remains: two *simultaneous* applies on the same notebook.
TODO 2 adds slow work to the model (a 20-second time_sleep: chapter 4
comes in handy), so you can stage the collision. Remember to copy the
updated main.tf to the colleague too, then from your side:

    tofu apply        # starts and stays busy ~20s

While it runs, from the colleague's terminal:

    tofu plan

Error acquiring the state lock — and below, the full name tag: lock ID,
path, Operation (OperationTypeApply), Who (user@machine). It is not a
failure: it is the lock doing its trade — one write at a time, everyone
else waits *knowing who is inside*. When your apply finishes, his plan
passes. (There is also tofu force-unlock <ID>: the break-glass hammer for
locks orphaned by a dead process — used after reading the name tag, never
out of impatience.)

### Phase 4 — The backend gallery (read)

Where notebooks live in the real world: s3 (+ native lock or DynamoDB),
azurerm and gcs (lock included), consul (the one you just used), pg
(PostgreSQL, advisory locks), http (a custom API), and the managed
services (HCP Terraform / remote backends). The choice criterion is
always the same triptych: durability, access control, locking.

### Cleanup

    tofu destroy      # from either folder: the notebook is one
    docker rm -f cap12-consul

## Definition of done

- After the migration: state list ok, local terraform.tfstate at zero
  bytes, and the book-labs/cap12 key present in Consul's KV.
- The colleague attached with no migration and his first plan said No
  changes, seeing your resources.
- During your slow apply, his plan failed with Error acquiring the state
  lock and the name tag (ID, Operation, Who).
- With your apply done, his plan worked again.
- You answered the three questions in answers.md.

## The three questions

**a.** The question «where»: what exactly does the backend block govern,
and why does changing it require init (and not apply)? In the migration:
what was copied, what stayed behind (the .backup), and why can the
backend block contain nothing about resources?

**b.** The colleague's second act: compare point by point with chapter
11's incident — what did his plan see then, what does it see now, and
which of the three sources of truth changed house to obtain this effect?
Why did the attach ask for no migration?

**c.** The lock: what exactly would it protect from with two simultaneous
applies (think of what would happen to the memory with two interleaved
writes)? Read the lock's name tag: what are ID and Who for, in team
practice? And when is force-unlock legitimate — and when is it just a way
to turn an orderly queue back into chaos?
