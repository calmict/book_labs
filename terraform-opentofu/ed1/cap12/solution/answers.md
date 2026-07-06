# Chapter 12 — Answers (model solution)

## The move (Phase 1)

    -rw-r--r--. 1 user user 0 ... terraform.tfstate      (zero bytes)
    "Value":"eyJ2ZXJzaW9uIjo0...                          (the state, base64,
                                                           in Consul's KV)

## The colleague, second act (Phase 2)

    random_pet.site
    No changes. Your infrastructure matches the configuration.

## The lock (Phase 3)

    Error: Error acquiring the state lock
      ID:        994d9673-cef5-a7de-b3b3-4c43e4981f23
      Path:      book-labs/cap12
      Operation: OperationTypeApply
      Who:       user@macrocky

    # after my apply finished: No changes — the queue moved on

## The three questions

**a. The question «where».**

The backend block governs the state's logistics, and only that: where the
notebook lives (a Consul key instead of a local file), through which
protocol it is read and written, and how writes are serialised (the
lock). It requires init because it is not a change to the desired world —
no resource is touched — but a change to the tool's own working setup:
the state must be physically moved before any plan can run again, and
init is the phase that prepares the working directory. The migration
copied the full state document (bindings, attributes, secrets included)
into the backend, and left behind an emptied local file plus a
terraform.tfstate.backup — the courtesy copy of what was moved. The block
cannot mention resources because it is read BEFORE the model is even
evaluated: it tells the tool where its memory is, and the memory must be
found before anything else makes sense.

**b. The colleague's second act.**

In chapter 11 his plan proposed to create everything: his memory was a
private, empty file, so my objects did not exist for him — and his apply
crashed into the reality mine had built. Now his plan says No changes:
same code, but the MEMORY changed house — from two private files to one
shared Consul key referenced by the backend block that travels in git
with the code. The three sources are one chain again for everyone: his
code equals mine, his memory IS mine, reality matches both. The attach
asked for no migration because migration is for moving an EXISTING state
into a new home: his local state was empty, so there was nothing to move
— init simply configured his working directory to read and write the
shared key.

**c. The lock.**

Two simultaneous applies would interleave read-modify-write cycles on the
same document: each would read a snapshot, compute against it, and write
back — the second write silently overwriting the first's bindings. The
result is a corrupted memory: resources that exist but are recorded by
neither, serials that lie, drift born inside the notebook itself. The
lock serialises writers: one at a time, everyone else fails fast with a
name tag. In team practice the tag is the difference between panic and a
coffee: Who tells you which colleague (or CI job) is inside, Operation
tells you what it is doing, and the ID is the exact handle you would pass
to force-unlock. Which is legitimate in one case only: the holder is
DEAD — a crashed process, a killed pipeline — and the lock is orphaned;
you read the tag, verify the holder cannot still be running, then break
the glass. Using it because a colleague's apply is slow is not unlocking:
it is re-enabling the interleaved writes the lock exists to prevent.
