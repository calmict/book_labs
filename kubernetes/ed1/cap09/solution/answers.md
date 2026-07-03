# Chapter 9 — Answers (model solution)

## The REST API without kubectl

    /api  -> "versions": ["v1"]                      (the core group)
    /apis -> "groups": apiregistration.k8s.io, apps, events.k8s.io, batch...

## The four rejections and the one welcome

    # anonymous curl
    "message": "namespaces is forbidden: User \"system:anonymous\" cannot
    list resource \"namespaces\" ...", "code": 403
    # with the certificates
    { "kind": "NamespaceList", ... }                 (a plain 200)
    # impersonating
    Error from server (Forbidden): pods is forbidden: User
    "system:serviceaccount:default:default" cannot list resource "pods" ...
    # the second pod against the quota
    Error from server (Forbidden): pods "sleeper2" is forbidden: exceeded
    quota: one-pod-only, requested: pods=1, used: pods=1, limited: pods=1

## The watch stream

    7 "type":"ADDED"      (the initial state, one event per namespace)
    2 "type":"MODIFIED"   (watch-lab entering Terminating)
    1 "type":"DELETED"    (watch-lab gone)

## The three questions

**a. Which gate rejected the anonymous curl, which one the impersonated
get, which one the second pod?**

The anonymous curl never got past the entrance: with no credentials the
request is mapped to system:anonymous, and it dies between authentication
and the first authorization check — nothing about you is trusted yet. The
impersonated get passed authentication (the apiserver knows exactly who is
asking) and was stopped at the second gate, authorization: RBAC found no
rule granting that service account a list on pods. The second pod passed
both — the admin may create pods in quota-lab — and was stopped at the
third gate, admission: the ResourceQuota plugin judged the request on its
merits and found the namespace full. Only requests that clear all gates
reach the fourth step, validation and persistence into etcd (chapter 8).

**b. 401 versus 403: who issues them and what different things do they
say?**

A 401 Unauthorized comes from the authentication layer and means "I do not
know who you are": missing or invalid credentials, conversation over. A 403
Forbidden comes later and means "I know exactly who you are, and the answer
is no" — from the authorization layer (no RBAC rule allows it) or from an
admission plugin (allowed in principle, rejected on the merits, like the
quota). On clusters where anonymous requests are enabled, an unauthenticated
call can surface as a 403 for system:anonymous rather than a 401: same
lesson, the identity just has a name.

**c. Why is the watch more efficient than polling, and what does it have to
do with chapter 7's reconciliation loop?**

Polling asks "anything new?" over and over, paying a full round trip and a
full list even when nothing changed — multiply that by every controller,
kubelet and scheduler, and the apiserver melts. The watch inverts it: one
long-lived connection, and the apiserver pushes each change exactly once,
as it happens. That is the mechanism under chapter 7's loop: the controller
did not discover the deleted Pod by rereading the world, it was notified by
its watch and reacted in milliseconds. List once, then watch: the pattern
the whole control plane is built on.
