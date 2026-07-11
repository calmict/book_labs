# Chapter 21 - Answers (model solution)

## The completed TODOs

    # TODO 1 (21.4) - inventory.docker.yml: group by the container labels
    keyed_groups:
      - key: docker_config.Labels['role'] | default('none')
        prefix: role
      - key: docker_config.Labels['env'] | default('none')
        prefix: env

    # TODO 2 (21.5) - inventory.docker.yml: a conditional group
    groups:
      production: "docker_config.Labels['env'] | default('') == 'prod'"

    # TODO 3 - site.yml: target the dynamically-built web tier group
    hosts: role_web

solution/run.sh proves it end to end against an isolated docker-in-docker engine: the
dynamic inventory discovers the live fleet without any name written; keyed_groups builds
role_* and env_* from the labels; groups builds a conditional production group; compose
makes the web tier reachable over the docker connection (ping pong); the play targets the
dynamic role_web group and touches only web1 and web2, not db1; and a rerun is idempotent.
Every container touched lives inside the dind, so no other container on the machine is
ever affected.

## The three questions

**a. Static as a photograph, dynamic as a mirror; the 3 a.m. autoscaler.**

A static inventory is a list you wrote at one moment and it keeps saying exactly that
until you edit it again: it is a photograph of the fleet as it was when you typed it, and
like a photograph it does not change when the world does. A dynamic inventory holds no
list at all - it holds instructions for asking the source of truth "who is here now?" and
rebuilds itself every time it runs, so it reflects the fleet as it actually is at that
instant: a mirror. When at 3 a.m. the autoscaler adds ten machines and removes five, the
photograph is now wrong in two directions at once - it still names five hosts that no
longer exist (so tasks against them hang or fail) and it knows nothing of the ten new ones
(so they go unconfigured, silently) - and it stays wrong until a human notices and edits
the file. The mirror simply shows fifteen where there were ten: the next command sees the
five gone and the ten arrived, with no edit and no human. Static is still perfectly fine
when the fleet does not move on its own - a fixed handful of long-lived servers, a
homelab, on-prem boxes with stable names - where the list rarely changes and writing it by
hand is clearer and needs no plugin, credentials, or provider round-trip. The cost of
dynamic (a plugin, access to the source, a query on every run) is worth paying exactly
when the fleet changes without you.

**b. Why target the group, not the names; web4.**

Because in a dynamic world the names are the thing most likely to change, and anything you
hard-code you will have to maintain by hand - which is the very toil dynamic inventory
exists to remove. If you write "run on web1, web2, web3", then the list is correct only
until the fleet moves: the day web2 is replaced by web7 your play silently skips the new
node and tries to reach a dead one, and every birth or death forces you back into the
playbook to edit a list - the address-book problem, moved from the inventory into the
tasks. Targeting "the role_web group" says what you *mean* - the web tier, whoever that is
right now - and lets keyed_groups answer *who* from the live labels each run. When web4 is
born with role=web, it lands in role_web at the next roll-call and the next play includes
it automatically: you do nothing. You never touch the playbook, never update a list, never
risk missing a node or hitting a ghost. Targeting by fixed name in a dynamic world is a
mistake because it re-introduces a hand-maintained list at the point of action, coupling
your automation to identities that are, by design, temporary; targeting by tag couples it
to *roles*, which are stable even as the machines filling them churn.

**c. compose as the chapter-20 arranger, applied to the inventory.**

Because compose is Jinja2 building variables from data, which is exactly what chapter 20's
arranger did - only there it shaped a config file from fleet data, and here it shapes the
*inventory* from the source's data. The source hands back raw facts about each container -
its labels, its network settings, its config - and compose runs expressions over those
facts to produce host variables that did not exist as such: service_role is not something
Docker stores, it is docker_config.Labels['role'] lifted into a clean variable by a filter,
the same map/default reshaping you did on services in chapter 20. And ansible_connection is
the sharper example: the raw data never says "reach me over the docker connection" - compose
*decides* that, setting the magic variable that governs how Ansible talks to each host, so
a fleet discovered from the daemon becomes a fleet you can actually run tasks on, with no
SSH, purely because an expression composed the right connection var. That is what compose
gives you that the raw source data cannot: it turns provider facts into the exact variables
your plays and connections need - names, connection settings, derived roles, computed hosts
- so the inventory arrives not just discovered but *ready to use*. keyed_groups and groups
decide membership; compose decides what each member *knows about itself*. It is the arranger
again: raw data in, meaningful shape out - this time the shaped thing is the inventory.
