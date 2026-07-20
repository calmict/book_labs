# Chapter 17 — Answers

## The completed TODOs

**TODO 1 (17.2) — name resolution on the custom network:**

    custom_name=$(docker exec "$A" sh -c "ping -c1 -w2 $B >/dev/null 2>&1 && echo OK || echo FAIL")

**TODO 2 (17.1) — no name resolution on the default bridge:**

    default_name=$(docker exec "$DA" sh -c "ping -c1 -w2 $DB >/dev/null 2>&1 && echo OK || echo FAIL")

**TODO 3 (17.3) — isolation, not even by IP:**

    b_ip=$(docker exec "$B" sh -c 'ip addr show eth0 | grep -w inet | grep -oE "[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+" | head -1')
    isolation=$(docker exec "$DA" sh -c "ping -c1 -w2 $b_ip >/dev/null 2>&1 && echo REACHED || echo BLOCKED")

## Reflection questions

**a. Why do names resolve on a custom network but not on the default bridge?**

When you create a user-defined bridge network, Docker attaches to it an embedded DNS
server, reachable inside every container of that network at 127.0.0.11. That resolver
knows the name (and network aliases) of every container on the network and answers
queries for them, so "ping web" finds the web container's current IP without you ever
knowing the number. The default bridge has no such resolver: containers there can
only reach each other by IP. The old --link flag used to inject the peer's name into
/etc/hosts, but it was static, per-pair and fragile; the network DNS replaces it,
which is why --link is deprecated. Names that resolve automatically are the reason you
almost always create a network rather than use the default bridge.

**b. What realises the isolation, and how do you cross it on purpose?**

Docker installs iptables rules (the DOCKER-ISOLATION chains) that drop traffic
between different bridge networks, so a container on one network cannot reach a
container on another even if it knows its IP — as the lab shows, a container off the
custom network is BLOCKED. This is a security property, not just organisation: it
means you can put the database on a back-end network the public web tier cannot even
address, limiting blast radius if a service is compromised. When you genuinely need a
container to span two networks — say an API that must talk to both a front-end and a
back-end network — you attach it to both with docker network connect, and it gets an
interface (and a name) on each.

**c. Why a per-application network, and how does it connect to Compose?**

A dedicated network per application gives you stable names instead of shifting IPs,
and isolation from everything else on the host. Inside it the web service reaches the
database as "db", regardless of restarts or which IP it got this time — no
configuration to update, no IP to hard-code. That is exactly the model Docker Compose
(chapter 20) uses: it creates a network for the app and puts every service on it, so
the compose file refers to services by name and never by address. Understanding the
custom bridge is understanding what Compose does for you under the hood.
