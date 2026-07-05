# Chapter 27 — Answers

## Injection

    # paste here: the pods, each with two containers (app + istio-proxy)

## mTLS STRICT

    # paste here: outside client refused (000), in-mesh client gets a response

## Canary

    # paste here: the counts of v1 vs v2 over ~30 requests (about 80/20)

## The three questions

**a. The problem and the two planes (27.1-27.2): why is network logic in
every app a problem, what changes with a sidecar, and what is the
difference between data plane and control plane?**

_(your answer)_

**b. mTLS (27.3): what did STRICT prove, where do the identities and
certificates come from, and how does this differ from and complement
chapter 22's NetworkPolicy?**

_(your answer)_

**c. Traffic management and observability (27.4-27.5): how does a canary
work without touching the app, what do retries and circuit breaking add,
and why is a mesh well placed for tracing?**

_(your answer)_
