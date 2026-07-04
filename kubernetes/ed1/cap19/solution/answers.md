# Chapter 19 — Answers (model solution)

## The request with no doorman

    curl http://localhost:8081  -> connection refused
    labs   nginx   uno.labs.local,due.labs.local   <ADDRESS empty>   80

## The door at work

    Host: uno.labs.local -> app-uno
    Host: due.labs.local -> app-due
    no Host header       -> HTTP 404
    labs   nginx   ...   localhost   80    <- ADDRESS populated now

## The doorman's words

    ... "GET / HTTP/1.1" 200 ... [default-uno-80] ... 10.244.0.5:8080 ...
    ... "GET / HTTP/1.1" 200 ... [default-due-80] ... 10.244.0.6:8080 ...
    (the chosen upstream, in brackets: the L7 decision, logged)

## The three questions

**a. L4 versus L7: what does a Service see, what does the Ingress see, and
why is host-based routing impossible at layer 4?**

A Service lives at layer 4: it sees a destination IP and port on a TCP
packet, and its whole vocabulary is "rewrite this destination" (chapter
18's DNAT). The Host header, the path, the method live INSIDE the HTTP
payload, which netfilter never parses: at L4 the two curls to
uno.labs.local and due.labs.local are indistinguishable — same IP, same
port. The Ingress controller terminates the TCP connection, reads the
HTTP request as an application would, and only then chooses the backend:
that is why one door can serve many names, and why it costs a proxy hop
that a plain Service does not pay.

**b. Why does Kubernetes accept objects nobody realises, and what do
Ingress-without-controller and chapter 10's controllers have in common?**

Because the API is a filing cabinet, not an execution engine: the
apiserver validates and stores desires (chapter 9), full stop. Every
behaviour in the system — replicas, schedules, routes — exists only
because some controller watches those desires and acts (chapter 10's
observe-diff-act). Your rules sat inert exactly like a Deployment would
sit inert if the controller-manager were stopped. This decoupling is the
extensibility secret: anyone can define new object kinds and ship a
controller for them, and Ingress itself is the proof — Kubernetes defines
the object, while nginx, traefik or HAProxy compete to be its executor
(ingressClassName picks which one).

**c. The full anatomy: the stations from curl to app-uno's pod.**

1. curl talks to localhost:8081 on the host — Docker's port mapping
   (extraPortMappings) decides, forwarding to port 80 of the node
   container. 2. On the node, the controller pod owns port 80 via
   hostPort: the packet enters nginx. 3. nginx reads the HTTP request —
   the L7 decision: Host uno.labs.local matches an Ingress rule, upstream
   default-uno-80. 4. nginx opens a new connection towards the backend:
   in kind's flavour it resolves the endpoints directly, in the general
   case it goes through the Service's ClusterIP — chapter 18's netfilter
   coin and DNAT. 5. The packet crosses the veth/bridge plumbing of
   chapter 6 and reaches the pod, which answers app-uno. Two proxies of
   different layers (Docker's L4 mapping, nginx's L7 routing) and one
   chain of chapters, end to end.
