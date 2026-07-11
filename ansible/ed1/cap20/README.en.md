# Chapter 20 — The arranger

**Level:** Advanced

So far you have *passed* data around: a variable here, a list there, a dictionary into a
template. But raw data rarely already has the shape you need: you have a list of services and
want only the enabled ones; you have a base configuration and a bundle of per-environment
changes, and you want them merged; you have a map and want to walk it line by line. Chapter 20
gives you the **arranger**: Jinja2 in its full form — the filters that transform, the tests
that ask, the lookups that fetch — and the .j2 templates that, from the data, write the
configuration *by themselves*. You stop writing configs by hand: the config becomes a
*function* of the data.

## Objectives

- The **three families**: filters, tests, lookups (20.1).
- **default and mandatory**: the safety net (20.2).
- Transforming data: **map, select, selectattr** (20.3).
- Working with dictionaries: **dict2items and combine** (20.4).
- The **tests**: is defined, is version and the others (20.5).
- The **.j2 templates**: configurations that write themselves (20.6).
- The **lookups**, finally in full (20.7).
- The **good habits** with Jinja2 (20.8).

## Prerequisites

- The chapter 6 venv (or start/requirements.txt).
- The templates and variables of chapter 12; the dictionary trap of chapter 13 (it returns
  here, with the cure: recursive combine).
- (No nodes: like chapter 13, everything resolves on the **control node** — connection: local.
  Jinja2 works where Ansible is.)

## The scenario

You have the raw data of a small fleet (start/data.yml): a list of services (name, environment,
port, whether enabled), a base configuration and a bundle of per-environment overrides. You
want a single application configuration to come out of it: the settings section merged from the
overrides, a block for each *enabled* service (in order), and the list of production ports. You
do not write it: the arranger writes it, from the data.

## Step by step

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    cd start

It runs node-less, passing the implicit localhost on the command line:

    ansible-playbook -i localhost, site.yml

### Phase 1 — The three families (20.1)

Inside the double braces, Jinja2 gives you three different tools:

- **Filters** (after the pipe |): they *transform* a value. name | upper, list | sort, ports |
  join(',').
- **Tests** (after is): they *ask*, answering true/false. x is defined, version is
  version('2.12','>=').
- **Lookups** (the lookup(...) function): they *fetch* a value from outside — environment, a
  file, a command, the vault of chapter 19.

Filters to reshape, tests to decide, lookups to go and fetch. Question a.

### Phase 2 — The safety net: default and mandatory (20.2)

A variable that is not there blows the template up with "undefined". Two nets:

- **default**: a fallback value. {{ region | default('eu-south-1') }} — if region is missing, it
  uses the fallback. With default('x', true) the fallback also kicks in when the variable is
  *empty*, not only when undefined.
- **mandatory**: the opposite. {{ api_key | mandatory }} — if it is missing, it *fails on
  purpose*, at once and with a clear message ("Mandatory variable 'api_key' not defined"),
  instead of proceeding with a hole.

default for what is optional, mandatory for what is required: make explicit which of the two.

### Phase 3 — Transforming data: map, select, selectattr (20.3 — TODO 1)

Here the arranger really works. Filters that chained together do wonders:

- **map(attribute='field')**: from a list of dictionaries it extracts *one* field. Services →
  names.
- **select / selectattr**: they *filter* the list, keeping only what passes a test.
  selectattr('enabled') keeps the enabled; selectattr('env','equalto','prod') keeps the prod.
  (reject/rejectattr do the opposite.)

Complete **TODO 1** in start/site.yml: derive the list of enabled services, which the template
will use —

    enabled_services: "{{ services | selectattr('enabled') | list }}"

Chain them and read the power: the names of the enabled prod services are
services | selectattr('enabled') | selectattr('env','equalto','prod') | map(attribute='name') | list.

### Phase 4 — Dictionaries: dict2items and combine (20.4 — TODO 2)

Two recurring problems with dictionaries:

- **Iterating** a dictionary in a loop: you cannot directly, but **dict2items** turns it into a
  list of {key, value} pairs you *can* loop over (and items2dict does the reverse).
- **Merging** two dictionaries: **combine**. Complete **TODO 2**: merge the base with the
  overrides —

      effective_config: "{{ base_config | combine(env_overrides) }}"

But beware the trap already seen in chapter 13: combine, by default, *replaces* rather than
merges on *nested* dictionaries. If base has server: {host, port} and override has server:
{port}, the plain combine *loses host*. The cure is combine(over, recursive=true), which goes
in and truly merges:

    shallow   = {'server': {'port': 8443}, 'tls': False}                    # host lost!
    recursive = {'server': {'host': '0.0.0.0', 'port': 8443}, 'tls': False} # host kept

The playbook shows them side by side — Question b.

### Phase 5 — The tests (20.5)

Tests answer true/false and live after is:

- **is defined / is undefined**: does the variable exist?
- **is version('2.12','>=')**: a *semantic* version comparison (not strings: it knows 2.12 >
  2.9). The playbook uses it to refuse to run on too old an ansible.
- and also is match / is search (regex), is in, is truthy. Tests are used inside the braces
  *and* in when conditions (without braces, ch. 15).

### Phase 6 — The template that writes itself (20.6 — TODO 3)

Now the arranger composes. The template start/templates/app.conf.j2 already has the settings
section (a loop over effective_config with dict2items) and the prod ports line. The heart is
missing: a block for each enabled service. Complete **TODO 3** —

    {% for s in enabled_services | sort(attribute='name') %}

    [{{ s.name }}]
    port = {{ s.port }}
    env = {{ s.env }}
    {% endfor %}

Render it (the playbook does it with the template module) and read the result: a complete,
sorted config, with only the enabled services — born *from the data*, not written by hand. You
change a datum, re-run, the config rewrites itself; and it is **idempotent**: if the data does
not change, changed=0.

    [settings]
    workers = 4
    timeout = 60
    loglevel = debug

    [api-01]
    port = 9090
    env = staging
    ...
    # allowed prod ports: 8080,8081,5432

### Phase 7 — The lookups, in full (20.7)

The lookup(...) fetches a value from *outside*, and you have already met it (env in ch. 19, the
vault). Now the catalogue:

- **env**: an environment variable. **file**: the contents of a file. **pipe**: the output of a
  command. **template**: renders another .j2. **password**: generates (and saves) a password.
  **url**: downloads. **first_found**: the first file that exists among many.

The lookup runs **on the control node**, once, when the line is evaluated — not on the managed
node. It is the way to *bring in* data that is not in the variables.

### Phase 8 — The good habits (20.8)

- **Do not overdo it in one line.** A chain of six filters is unreadable: break it into
  intermediate variables with meaningful names (enabled_services, effective_config).
- **Put the nets in**: default for the optional, mandatory for the required; do not let an
  undefined blow up in your face in production.
- **Recursive combine** when the dictionaries are nested (ch. 13).
- **The logic lives in the data and the template**, not scattered across twenty tasks: a
  template that writes itself is easier to read than twenty set_fact.

## Done when

- enabled_services (TODO 1) keeps only the services with enabled true.
- effective_config (TODO 2) merges base and overrides (timeout 60, loglevel debug).
- The rendered app.conf contains the [settings] section with the overrides, a block for
  api-01/db-01/web-01 (in order, **not** web-02 which is disabled), and "allowed prod ports:
  8080,8081,5432".
- On a rerun → changed=0 (the template is idempotent).
- The playbook runs in connection: local, with no nodes.

## Questions to reflect on

**a.** The three families of Jinja2 — filters, tests, lookups — do different things: transform,
ask, fetch. For each, an example from the scenario, and why they are not interchangeable (why
selectattr is not a test, why is version is not a filter)?

**b.** In chapter 13 you saw that a higher precedence level *replaces* the whole dictionary.
Here combine, by default, does the same on nested dictionaries. Why is combine(recursive=true)
the cure, what would you lose without it, and how is it *different* from the precedence problem?

**c.** The template renders a config "that writes itself" from the data. What do you gain over
writing app.conf by hand — when you add a service, when you change a value for all of them, when
you must render the same schema for ten environments? And where is the limit (when does a
template become too clever)?

## Cleanup

Nothing to tear down: no nodes, no containers. The rendered config lands in
/tmp/cap20-lab/app.conf (or wherever CAP20_OUT points); delete it if you like.

## Where it leads

You can shape data and make configurations grow out of it. But so far the fleet's data you
*wrote yourself*, by hand, in the inventory. In the real world the fleet changes on its own:
machines that are born and die in the cloud. **Chapter 21** opens **dynamic inventories** — the
inventory no longer written by hand, but *generated* by querying whoever really knows the
machines (the cloud provider), and today's filters will serve to give it shape.
