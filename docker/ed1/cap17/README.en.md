# Chapter 17 — The private switchboard

**Level:** Advanced

In chapter 16 you saw the shared switchboard: the docker0 bridge, where every
container has a number (an IP) but no name. Fine for understanding the mechanism,
poor for building on: IPs change on every restart, and every container lands on the
same public board. The answer is to open a private switchboard — a bridge network you
define. There Docker adds two things that change everything: a directory (an embedded
DNS, so containers call each other by name) and an isolated line (containers on one
network do not see those on another). In this lab you contrast the two worlds: on the
default bridge names do not work, on your bridge they do, and whoever is off the
network stays out.

## Objectives

- See that on a bridge network you define, containers resolve one another by name
  (embedded DNS) (17.2).
- Verify that on the default bridge name resolution does not work (17.1).
- Observe the isolation: whoever is not on the network cannot reach its containers,
  not even by IP (17.3).
- Understand why a per-application network is the right choice (17.4).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use
  Docker.
- Chapter 16 (network namespaces, veth, bridge): here the bridge becomes a network
  with a name and rules.

## The scenario

In start/ you will find irete.sh: a script that creates a custom network, starts
containers on it and on the default bridge, and should measure name resolution and
isolation — but the three key proofs are missing. You fill three gaps (TODO 1..3). A
uniquely named network and throwaway containers, both removed at the end; the default
bridge is not touched and the daemon is not restarted.

Prepare the environment:

    cd docker/ed1/cap17/start

### Phase 1 — The directory: names on the custom bridge (17.2 — TODO 1)

Open start/irete.sh and complete **TODO 1**: on the custom network, have container A
reach container B **by name**. The network's embedded DNS resolves the container's
name: ping by name works.

    custom_name=$(docker exec "$A" sh -c "ping -c1 -w2 $B >/dev/null 2>&1 && echo OK || echo FAIL")

### Phase 2 — No directory on the default (17.1 — TODO 2)

Complete **TODO 2**: on the default bridge, try to reach another container by name.
There is no embedded DNS: the name does not resolve, and the ping fails.

    default_name=$(docker exec "$DA" sh -c "ping -c1 -w2 $DB >/dev/null 2>&1 && echo OK || echo FAIL")

### Phase 3 — The isolated line (17.3 — TODO 3)

Complete **TODO 3**: take B's IP (on the custom network) and try to reach it from a
container that is NOT on that network. It is blocked: the networks are isolated, not
even the IP gets through.

    b_ip=$(docker exec "$B" sh -c 'ip addr show eth0 | grep -w inet | grep -oE "[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+" | head -1')
    isolation=$(docker exec "$DA" sh -c "ping -c1 -w2 $b_ip >/dev/null 2>&1 && echo REACHED || echo BLOCKED")

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- irete.sh checks name resolution on the custom network (TODO 1).
- It checks that on the default bridge the name does not resolve (TODO 2).
- It checks that a container off the network cannot reach B, not even by IP (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — the network's DNS: on the custom network, A reaches B by name (result
  OK).
- **OK 2** — no DNS on the default: on the default bridge, the name does not resolve
  (result FAIL).
- **OK 3** — isolation: a container off the custom network cannot reach B even by IP
  (result BLOCKED).

## Reflection questions

**a.** On the default bridge containers do not resolve one another by name, on a
network you define they do: what makes the difference? Where does the embedded DNS
live (the address 127.0.0.11 inside the container) and why is the old --link
mechanism deprecated in its favour?

**b.** Two custom networks, or a custom one and the default, do not talk to each
other by default: which daemon rules realise this isolation, and why is it a security
property and not just tidiness? How would you deliberately connect a container to
more than one network (docker network connect)?

**c.** In a multi-service application (the web talking to the database), why is a
dedicated custom network better than the default bridge? How does this connect to the
stable service names of Docker Compose (chapter 20), where you never use IPs?

## Cleanup

Nothing to tear down by hand: the containers are removed by the script (docker rm -f)
and the uniquely named custom network is removed (docker network rm), all with a
safety trap. The default bridge is never touched. The busybox base image stays in
cache. The daemon is never restarted.

## Where it leads

You have two ways to connect containers: the public switchboard and your private one,
with a directory and isolation. The edge cases remain: what if a container wanted no
network isolation at all, or on the contrary no network whatsoever? **Chapter 18**
covers the other drivers — host (the container shares the host's stack, with no
namespace of its own) and none (a namespace with no cable) — and how to choose. For
the command reference, see the volume's appendices.
