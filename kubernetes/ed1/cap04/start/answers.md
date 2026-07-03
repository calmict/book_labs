# Chapter 4 — Answers

## The image laid bare

    # paste here the output of find image -type f
    # and note which blob is the config and which is the layer

## Copy-on-write: the evidence

    # paste here ls -l upper/etc/ after the change and the deletion
    # (the modified motd and the whiteout for hostname)

## Capabilities and kernel

    # paste here the two CapEff lines (container vs host),
    # the error of date -s, and the two uname -r outputs

## The three questions

**1. What does an OCI image really contain? Follow the chain
manifest → config → layer.**

_(your answer)_

**2. Where did the change and the deletion of step 4 end up, and why does
this make containers disposable?**

_(your answer)_

**3. Why can "root" in the container not change the system clock, and what
does the identical uname -r inside and outside have to do with it?**

_(your answer)_
