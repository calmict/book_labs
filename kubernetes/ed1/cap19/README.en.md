# Chapter 19 — The Door and the Doorman

**Level:** Intermediate

After chapter 18's Services, the building has many entrances but still cannot read the name written
inside an HTTP request. Here you separate declarative rules from their executor and observe L7 routing.

## Objectives

- Distinguish Service L4 load balancing from Ingress host and path routing (19.1).
- Declare two Ingress rules and prove they remain inert without a controller (19.2, 19.3).
- Install Traefik and follow a request to the correct Service and Pod (19.3, 19.4).

## Prerequisites

- Chapter 18 completed; Docker, kind, kubectl, curl, and network access.
- At least 3 GiB free on Docker's filesystem for the dedicated cluster.
- A free local port; run.sh chooses one from 18081 upward, or uses CAP19_PORT.

## The scenario

Two applications share the same IP address and port. Complete TODOs 1..3 in start/ingress.yaml by
declaring the two hosts, paths, and backends. The test creates the dedicated book-labs-ingress cluster,
applies the rules without a controller, and then installs Traefik 3.7.12 from a local manifest.
JSON access logs are enabled to make the L7 decision observable.

    cd kubernetes/ed1/cap19/solution
    ./run.sh

### Phase 1 — Rules without a doorman (19.2, 19.3)

The first check applies the Ingress while no controller exists: the port does not answer and ADDRESS
remains empty. This is the counterexample proving that the object declares intent but cannot enact it.

### Phase 2 — One door, two hosts (19.1, 19.2)

Traefik reads the Host header and sends uno.labs.local to app-uno and due.labs.local to app-due.
An unknown host receives the default backend's 404 response.

### Phase 3 — The anatomy (19.4)

The test finds the latest request in the controller log, connecting port mapping, controller, L7
decision, Service, and Pod.

## Definition of "done"

- [ ] The three TODOs in start/ingress.yaml are complete.
- [ ] Without a controller the rule is inert; with it, the two hosts reach different applications.
- [ ] run.sh prints OK 1..6 and ALL CHECKS PASSED.

## How it is verified

- OK 1 proves the gate bites: without a controller there is no routing and ADDRESS is empty.
- OK 2 verifies that Traefik 3.7.12 becomes Ready.
- OK 3 and OK 4 verify the two hosts on the same IP address and port.
- OK 5 verifies the 404 response for an unknown host.
- OK 6 finds the requested host and selected Kubernetes backend in the same JSON access log.

## Reflection questions

**a.** What can an L4 Service see, what can an L7 Ingress see, and why does host routing require L7?

**b.** Why does Kubernetes accept an Ingress that no controller realizes? How does this echo chapter
10's reconciliation loop?

**c.** Which stations does the request cross from curl to app-uno's Pod, and who decides at each one?

## Cleanup

run.sh deletes the kind cluster it creates and restores the previous kubectl context. If the dedicated
cluster already existed, it removes only the namespaces used by the lab.

## Where this leads

Routing connected requests to applications; chapter 20 applies the same decoupling to storage by
separating what an application requests from the real volume the cluster assigns.
