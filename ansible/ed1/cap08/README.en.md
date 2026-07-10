# Chapter 8 — The address book

**Level:** Foundational

The conductor has the baton (ch. 6) and the rulebook (ch. 7), but does not yet know
**who** the players are. The **inventory** is the address book: the host names,
their addresses, the **groups** they play in. It is the file that turns "a container
on port 2281" into **web1**, and "web1 and web2" into **web** — so from here on you
say *ansible web* and not a list of IPs. In this lab you write it in INI, verify it
with the right tools, and at the end the conductor calls the roll: **ping the whole
fleet, by name**.

## Objectives

- What an inventory is; the **INI** format (hosts, groups, variables) and the
  **YAML** equivalent.
- **Groups of groups** with :children.
- The **host patterns**: groups, exclusions (web:!web2), combinations.
- The **ranges**: edge[01:03] — three hosts in one line.
- Host and group variables **in the inventory**, and the tidy form: the
  **group_vars/** and **host_vars/** directories.
- The **magic groups** all and ungrouped; verification with **ansible-inventory**.

## Prerequisites

- The chapter 6 venv (or rebuild it with start/requirements.txt).
- Docker for the three nodes. Network on first boot (apt on the nodes).

## The scenario

Three players: **web1** and **web2** (the web section), **db1** (the db section).
Together they form **prod**. The address book also has an **edge** section of three
*fictional* hosts — they will serve to see ranges and to understand that the address
book can be read and queried even when the hosts do not exist.

## Step by step

### Phase 0 — Power the nodes on

    bash start/nodes.sh up

Three SSH containers (ports 2281, 2282, 2283), an ephemeral key in
/tmp/cap08-lab/key. They are the chapter 2 managed nodes, three times over.

### Phase 1 — TODO 1: the names and the sections

Open start/inventory.ini. The [db] section is already written as an example:

    [db]
    db1 ansible_port=2283

Complete **TODO 1**: the [web] section with web1 (port 2281) and web2 (port 2282).
Note the form: **a logical name** + its per-host variables on the same line. The
name (web1) is how *you* call the host; where it really is is told by the variables
(here all on 127.0.0.1, only the ports change — user, key and lab SSH options live
in [all:vars] at the bottom of the file, already there).

### Phase 2 — TODO 2: the group of groups

Complete **TODO 2**: the **prod** group that contains web and db — not hosts,
*groups*:

    [prod:children]
    web
    db

:children says "the members of this group are other groups". That is how the address
book scales: tomorrow you add web3 to [web], and prod inherits it for free.

### Phase 3 — Verify: the tree and the patterns

Never trust an unverified address book. The tool is ansible-inventory:

    ansible-inventory -i inventory.ini --graph

    @all:
      |--@prod:
      |  |--@web:  web1, web2
      |  |--@db:   db1
      |--@edge: ...

The tree says it all: who is where, what inherits from what. Then the **patterns** —
the target of every command is a pattern, and --list-hosts shows it to you *without
connecting*:

    ansible -i inventory.ini web --list-hosts         # a group
    ansible -i inventory.ini 'web:!web2' --list-hosts  # web MINUS web2
    ansible -i inventory.ini all --list-hosts          # everyone

The :! exclusion is the pattern you will use the day web2 is broken and you want to
act on all the others.

### Phase 4 — Ranges: three hosts in one line

Look at the [edge] section, already written:

    [edge]
    edge[01:03].lab.internal

    ansible -i inventory.ini edge --list-hosts

Three hosts: edge01, edge02, edge03. They do not really exist — and it does not
matter: the address book is a *document*, you can write and query it before the
machines are born. Ranges work alphabetically too ([a:c]) and are the way to declare
a numbered fleet without writing a hundred lines.

### Phase 5 — TODO 3: variables leave the address book

The per-line variables (Phase 1) are fine for the address; for everything else they
clutter the file. The tidy form: next to the inventory, a **group_vars/** directory
with one file per group. Complete **TODO 3**: create group_vars/web.yml with

    http_port: 8080
    greeting: hello from the web section

and verify web1 *sees* it:

    ansible -i inventory.ini web1 -m debug -a 'var=greeting'

The debug module prints the variable: web1 **inherited it from the web group**.
There is also host_vars/ (one file per host). The rule of order: in the inventory
only *who you are and where you live*; in group_vars/host_vars *what you are made
of*. (Precedence between these levels is chapter 13.)

### Phase 6 — The magic groups

Two groups always exist without declaring them: **all** (everyone) and **ungrouped**
(whoever is in none of your groups). Try:

    ansible -i inventory.ini ungrouped --list-hosts

Zero hosts: all of yours are in a section. Add a lone line at the top of the file
(outside any section) and re-run: there it is in ungrouped. It is the spy-group of
forgotten hosts.

### Phase 7 — The roll call

The moment it was all built for:

    ansible -i inventory.ini prod -m ping

    web1 | SUCCESS => "ping": "pong"
    web2 | SUCCESS => "ping": "pong"
    db1  | SUCCESS => "ping": "pong"

Three pongs. Ansible read the address book, opened three SSH connections **in
parallel** (ch. 7's forks), ran the module with each node's Python (ch. 2's
journey) — and you called the fleet **by name**. Note what you did NOT do: no IP, no
port, no ssh command typed by hand.

## Done when

- ansible-inventory --graph shows **prod → web(web1,web2) + db(db1)** and edge with
  the 3 range hosts.
- The patterns answer: web → 2 hosts, 'web:!web2' → 1, ungrouped → 0.
- group_vars/web.yml exists and debug prints greeting on web1.
- **ansible prod -m ping → 3 SUCCESS**.

## Questions to reflect on

**a.** INI and YAML describe the same address book. When would you prefer one over
the other? (Think: short files vs deep structures, and who else has to read it.)

**b.** Why are commands given to **groups** and not to hosts? What does writing
ansible web instead of ansible web1,web2 buy you the day the fleet goes from 3 to
300 hosts?

**c.** Variables can sit on the host line, in [group:vars], or in group_vars/. Why
is the directory the form that scales best — and what *new* problem does having the
same variable defined in several places introduce? (A preview of chapter 13.)

## Cleanup

    bash start/nodes.sh down

## Where it leads

The address book is there and answers the roll. In chapter 9 come the **ad-hoc
orders**: one command, one module, the whole fleet — ping was only the first. And
the inventory you wrote here is the same one chapter 21 will make *dynamic*:
generated from the cloud instead of written by hand.
