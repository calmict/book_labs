# Chapter 5 — Answers

## The parent chain

    # paste here the chain printed by the /proc loop of step 2
    # (and note where it stops)

## containerd, queried directly

    # paste here the output of: sudo ctr --namespace moby task ls

## The OCI bundle

    # note here where in config.json you found the sections
    # namespaces / resources / capabilities

## The three questions

**a. Who is the direct parent of the container process, why do neither
dockerd nor containerd appear in the chain, and what is the shim for?**

_(your answer)_

**b. Reconstruct who calls whom when you type docker run, and explain what
the "moby" drawer seen through ctr demonstrates.**

_(your answer)_

**c. Where in config.json did you find the ingredients of chapters 2-4?
And what happens to runc after it has started the container?**

_(your answer)_
