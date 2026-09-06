# Chapter 19 — Answers (model solution)

## The completed TODOs

TODO 1 (19.2) replaces the empty rules list with two HTTP hosts,
uno.labs.local and due.labs.local.

TODO 2 (19.2) gives each host a Prefix path rooted at /, so the whole site
matches rather than only one exact URL.

TODO 3 (19.2) completes each backend with its Service, uno or due, on port
80. The controller can now turn the declarations into two real routes.

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
the object, while Traefik, HAProxy, and other implementations compete to be its executor
(ingressClassName picks which one).

**c. The full anatomy: the stations from curl to app-uno's pod.**

1. curl talks to localhost:8081 on the host — Docker's port mapping
   (extraPortMappings) decides, forwarding to port 80 of the node
   container. 2. On the node, the controller pod owns port 80 via
   hostPort: the packet enters Traefik. 3. Traefik reads the HTTP request —
   the L7 decision: Host uno.labs.local matches an Ingress rule and selects
   lab-cap19-uno-80@kubernetes. 4. Traefik opens a new connection towards
   one of the Service endpoints. 5. The packet crosses the veth/bridge plumbing of
   chapter 6 and reaches the pod, which answers app-uno. Two proxies of
   different layers (Docker's L4 mapping, Traefik's L7 routing) and one
   chain of chapters, end to end.
