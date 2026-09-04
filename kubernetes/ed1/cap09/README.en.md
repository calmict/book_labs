# Chapter 9 — Knock at the four gates: the API server bare-handed

**Level:** Foundational

Etcd stores the truth, but only the API server may touch it. Here you use curl to see the gates a
request crosses and the stream that reports every change.

## Objectives

- Explore REST groups, versions, and resources without kubectl interpretation (9.1).
- Distinguish authentication, authorization, and admission by their responses (9.2-9.3).
- Observe ADDED and DELETED events over one watch connection (9.4).

## Prerequisites

- A cluster reachable with kubectl and chapters 7-8 completed.
- curl and base64. The check selects a free local port starting at 8001.

## The scenario

Complete start/api-lab.sh. Open kubectl proxy, but use curl to speak to /api, /apis, and the real
HTTPS server.

### Phase 1 — The REST API (9.1 — TODO 1)

Read /api and /apis through the proxy and recognise the core v1 group and the apps group.

### Phase 2 — The gates (9.2-9.3 — TODO 2)

Compare four requests: with an invalid token, using kubeconfig certificates, impersonating the default service
account, and creating a second Pod over quota. Keep each response's HTTP code and message.

### Phase 3 — The stream (9.4 — TODO 3)

Open a namespace watch, create and delete watch-lab, and locate its ADDED and DELETED events on the
same connection. Run the automated check:

    bash kubernetes/ed1/cap09/solution/run.sh

## Definition of "done"

- You explored /api and /apis with curl.
- You distinguished authentication 401, certificate access, RBAC Forbidden, and exceeded quota.
- run.sh prints OK 1..7 and ALL CHECKS PASSED.

## How it is verified

- OK 1 checks REST groups; OK 2 the 401 rejection of an invalid token; OK 3 certificate access.
- OK 4 is the authorization gate; OK 5 is the quota admission gate.
- OK 6 requires ADDED and DELETED events on the same watch.
- OK 7 checks namespaces, local processes, and temporary credentials.

## Reflection questions

**a.** Which gate corresponds to each of the four collected responses?

**b.** What do HTTP 401 and 403 say differently, and why can a credential-free request appear as system:anonymous?

**c.** Why is LIST plus WATCH more efficient than polling, and how does it feed reconciliation?

## Cleanup

The check stops proxy and watch, deletes temporary certificates, and removes quota-lab and
watch-lab. For the manual path, remove the same namespaces and stop both processes with Ctrl-C.

## Where it leads

You saw how change enters the cluster and how it is reported. Chapter 10 opens the controllers that
receive those signals and reconcile reality.
