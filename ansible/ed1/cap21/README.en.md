# Chapter 21 — The roll-call

**Level:** Advanced

In chapter 8 you wrote the address book by hand: a file with the nodes, one per line. It works
as long as the fleet stands still. But in the real world the fleet *moves on its own*: machines
that are born when load rises and die when it drops, in the cloud, while you sleep. A
hand-written address book is stale the moment you save it. The answer is to flip the mechanism:
instead of *listing* the nodes, you have them **answer a roll-call** — Ansible asks whoever
really knows the fleet (the provider) "who is here now?", and builds the inventory *on the
spot*. Here the provider is the Docker daemon, and the fleet is containers that come and go; but
AWS, Azure, GCP work identically.

## Objectives

- Static versus dynamic: the **mindset shift** (21.1).
- The mechanism: the **inventory plugins** (21.2).
- The first dynamic inventory on **AWS** (21.3, gallery).
- The real magic: grouping with **keyed_groups** (21.4).
- **groups and compose**: the Jinja2 filters at work (21.5).
- Readable names and performance: **hostnames and cache** (21.6).
- The **good habits** with dynamic inventories (21.7).

## Prerequisites

- The chapter 6 venv, plus the docker and requests libraries (in start/requirements.txt).
- The community.docker collection (you install it, as in chapter 17).
- The Jinja2 filters of chapter 20: they return here, to give the inventory shape.
- Docker: the fleet lives in an **isolated Docker engine** (docker-in-docker), so the plugin
  sees *only* the lab nodes and never any other container on the machine.

## The scenario

The nodes.sh script starts an isolated Docker engine — our "cloud" — and puts three containers
inside it with **labels** (role=web/db, env=prod/staging): they are the fleet's machines, and
the labels are the cloud *tags*. You write an inventory file that lists no node: it only says
*how to ask for them*. Ansible queries the engine, discovers the three containers, and groups
them by label on its own — then you talk to them without SSH, over the docker connection.

First bring the fleet up and export the isolated engine's address (nodes.sh prints it):

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    ansible-galaxy collection install -r start/requirements.yml
    cd start
    ./nodes.sh up
    export DOCKER_HOST=tcp://127.0.0.1:23751

### Phase 1 — Static versus dynamic (21.1)

Look at the two address books side by side:

    ansible-inventory -i inventory.ini --graph          # static: the nodes you WROTE
    ansible-inventory -i inventory.docker.yml --graph   # dynamic: the nodes that ARE THERE

The first lists what you put in, and stays identical even if a node died an hour ago. The second
lists nothing: it *goes and asks*, and returns the fleet alive right now. Static = a photograph;
dynamic = a mirror. Question a.

### Phase 2 — The mechanism: the inventory plugins (21.2)

The dynamic file is not a list, it is the **configuration of a plugin**. The first line says
which one:

    plugin: community.docker.docker_containers
    docker_host: tcp://127.0.0.1:23751

The plugin (one per source: docker, aws_ec2, azure_rm, gcp_compute...) knows how to query *that*
source and turn the answer into hosts, groups and variables. You pass the file to -i as you would
a static address book: Ansible recognises it as a plugin config and runs it. (The plugin must be
*enabled*: see ansible.cfg, section [inventory].)

### Phase 3 — AWS, the real case (21.3, gallery)

In the real world the source is often AWS. In start/gallery/aws_ec2.yml.example you find the
shape — plugin: amazon.aws.aws_ec2, regions, filters, grouping by tag — which we do *not* run
(it needs an AWS account), but is identical in design to the docker one: the plugin and the
source change, not the idea. What you learn here holds there.

### Phase 4 — The real magic: keyed_groups (21.4 — TODO 1)

Discovering the nodes is half; the other half is **grouping them by themselves**. keyed_groups
creates groups *from a datum* of each host — here, the container labels (the cloud tags).
Complete **TODO 1** in inventory.docker.yml:

    keyed_groups:
      - key: docker_config.Labels['role'] | default('none')
        prefix: role
      - key: docker_config.Labels['env'] | default('none')
        prefix: env

Now, without writing a single name, the groups role_web, role_db, env_prod, env_staging exist —
and they populate themselves as containers are born. Add a container with role=web and it will
show up in role_web at the next roll-call. Question b.

    ansible-inventory -i inventory.docker.yml --graph

### Phase 5 — groups and compose: Jinja2 at work (21.5 — TODO 2)

Two more tools, and this is where the chapter 20 filters come back:

- **groups**: creates a group when a Jinja2 *condition* is true. Complete **TODO 2**: a
  production group for the nodes with env=prod —

      groups:
        production: "docker_config.Labels['env'] | default('') == 'prod'"

- **compose**: builds *host variables* from Jinja2 expressions. The essential use is already
  given in the file: compose sets ansible_connection to the docker connection (so you talk to the
  containers without SSH), and derives service_role from the label:

      compose:
        ansible_connection: "'community.docker.docker'"
        service_role: "docker_config.Labels['role'] | default('unknown')"

keyed_groups groups, groups decides, compose enriches — the three ways to give *meaning* to the
raw nodes that arrive from the source.

### Phase 6 — Readable names and cache (21.6)

- **hostnames**: what to take the host's *name* from. A Docker id is unreadable; the file gives
  hostnames: [docker_name], so you see cap21-web1, not 3f9a2c... . On AWS you would pick the Name
  tag or the private IP.
- **cache**: querying the provider on every command is costly (on AWS, API calls against
  thousands of instances). The **cache** keeps the answer for a while, so later commands are
  instant. It is a plugin option (cache: true + a cache plugin); very handy in production, one to
  list among the good habits.

### Phase 7 — Using the dynamic groups (TODO 3)

An inventory exists to *act*. Complete **TODO 3** in site.yml: point the play at the group
keyed_groups built for the web tier —

    hosts: role_web

Run it:

    ansible-playbook -i inventory.docker.yml site.yml

The play touches *only* web1 and web2 (not db1), writes the marker, and is idempotent (on a
rerun, changed=0). You named not a single host: you said "the web tier", and the roll-call did
the rest.

### Phase 8 — The good habits (21.7)

- **Do not trust names, trust tags.** In a dynamic inventory hosts come and go: target by group
  (role_web, production), never by a fixed name.
- **Turn on the cache** when the source is slow or large, but remember it *can lie* (it shows the
  last photo): flush it when you need the fresh datum.
- **Readable hostnames** and meaningful keyed_groups: a dynamic inventory reads well only if you
  design it well.
- **The same mindset for every cloud**: once you know the mechanism (plugin + keyed_groups +
  compose), you change only the plugin to go from docker to AWS, Azure, GCP.

## Done when

- The dynamic inventory discovers the three fleet containers (cap21-web1/web2/db1) without you
  writing their names.
- keyed_groups (TODO 1) creates role_web (web1, web2), role_db (db1), env_prod (web1, db1),
  env_staging (web2).
- groups (TODO 2) creates production with web1 and db1 (the only env=prod).
- compose makes every node reachable over the docker connection: ansible role_web -m ping → pong.
- site.yml (TODO 3) on role_web touches only web1 and web2; on a rerun → changed=0.

## Questions to reflect on

**a.** A static inventory (ch. 8) and a dynamic one describe the same fleet. Why is the first "a
photograph" and the second "a mirror", and what happens to each when at 3 a.m. the autoscaler
adds ten machines and removes five? When is static still perfectly fine?

**b.** keyed_groups creates groups from a datum of the host (here the label, on AWS the tag). Why
is it more robust to target "the role_web group" than to list web1, web2, web3 by hand? What do
you no longer have to do when web4 is born, and why is targeting by fixed name a mistake in a
dynamic world?

**c.** compose builds host variables with Jinja2, and in the lab you use it to set the connection
(docker instead of SSH) and to derive service_role from the label. In what sense is this "the
same arranger as chapter 20" applied to the inventory instead of to a config file? And what does
compose let you do that the source's raw data, on its own, would not give you?

## Cleanup

    ./nodes.sh down        # removes the isolated engine, and the whole fleet with it

The docker-in-docker engine is isolated: switch it off and the three containers vanish with it,
and no other container on your machine was ever touched.

## Where it leads

You can discover the fleet instead of listing it. But so far you have assumed every task
succeeds: what about when a node, among the thousand at the roll-call, does not answer, or a
command fails halfway? **Chapter 22** opens **error handling** — block/rescue/always,
until/retries, assert/fail — to orchestrate a fleet where something, sooner or later, will go
wrong.
