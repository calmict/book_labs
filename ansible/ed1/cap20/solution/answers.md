# Chapter 20 - Answers (model solution)

## The completed TODOs

    # TODO 1 (20.3) - site.yml vars: keep only the enabled services
    enabled_services: "{{ services | selectattr('enabled') | list }}"

    # TODO 2 (20.4) - site.yml vars: merge base config with the overrides
    effective_config: "{{ base_config | combine(env_overrides) }}"

    # TODO 3 (20.6) - templates/app.conf.j2: a block per enabled service, sorted
    {% for s in enabled_services | sort(attribute='name') %}

    [{{ s.name }}]
    port = {{ s.port }}
    env = {{ s.env }}
    {% endfor %}

solution/run.sh proves it node-less (connection: local, no containers): the template
renders app.conf; combine applied the overrides (timeout 60, loglevel debug);
selectattr kept only the enabled services, sorted by name, with the disabled web-02
excluded; selectattr(env=prod) + map(port) produced the prod ports line; recursive
combine merged the nested dict where a shallow combine would have dropped 'host'; and
a second run changes nothing (the template is idempotent).

## The three questions

**a. The three families - filters, tests, lookups - and why they are not interchangeable.**

They answer three different needs. A filter *transforms* a value: it takes something and
gives back a reshaped something, after the pipe - services | map(attribute='name') |
sort turns the list of service dicts into a sorted list of names. A test *asks* a
yes/no question about a value, after is - ansible_version.full is version('2.12','>=')
answers whether the running ansible is recent enough, and is defined whether a variable
exists. A lookup *fetches* a value from outside the play - lookup('env','HOME') reaches
into the environment, lookup('pipe','date +%Y') runs a command and returns its output.
They are not interchangeable because they occupy different grammatical slots and return
different kinds of thing: selectattr is a filter (it returns a filtered sequence), not a
test - you cannot write x is selectattr, and selectattr('enabled') needs a sequence to
work on, not a single value to judge; is version is a test (it returns a boolean), not a
filter - you cannot pipe into it to reshape data, its whole job is to yield true or
false for a when or an assert. Reshaping, deciding, and fetching are distinct verbs, and
Jinja2 gives each its own construct: | for filters, is for tests, lookup() for lookups.
Reach for the one whose verb matches what you actually need.

**b. Why combine(recursive=true), and how it differs from the precedence problem.**

Because combine, by default, is shallow: when both dictionaries have a key whose value is
itself a dictionary, it does not merge those inner dictionaries, it takes the override's
whole inner dictionary and drops the base's. So base_nested has server: {host, port} and
over_nested has server: {port}; a plain combine yields server: {port} - host is gone,
silently, because the entire 'server' sub-dict was replaced, not merged. combine(over,
recursive=true) descends into matching sub-dictionaries and merges them key by key, so
host survives and only port is updated: exactly what you meant. Without recursive you
lose every base key that lives under a shared nested key, and the loss is quiet - the
render simply comes out missing a line. This is the same shape of trap as chapter 13,
where a higher-precedence dictionary replaced a lower one whole rather than merging, and
the cure there was also combine - but the two are different in *where* the replacement
happens. In chapter 13 it was Ansible's variable precedence deciding, across sources,
that the winning definition of a dict replaces the loser entirely, before your tasks even
run; here it is the combine filter itself, inside a single expression you wrote,
replacing at the nested level unless you ask it to recurse. One is a property of how
variables are resolved; the other is a property of how the filter merges. Knowing both,
you reach for combine to fix the precedence loss and for recursive=true to fix combine's
own shallow default.

**c. What a self-writing template gains, and where the limit is.**

You gain that the configuration stops being a thing you maintain and becomes a thing the
data produces. Add a service: you append one entry to data.yml and re-render - you do not
hunt through app.conf to place a block by hand, and you cannot forget to. Change a value
for all of them: you change it once in base_config or env_overrides, and every rendered
block reflects it, instead of a find-and-replace across a file where you might miss one.
Render the same schema for ten environments: the template is written once and fed ten
different data files, so the ten configs are guaranteed to share structure and differ
only where the data differs - no copy-paste drift. And because the render is idempotent,
re-running when nothing changed reports changed=0, so the config file is trustworthy: it
always matches the data. The limit is the other side of the same coin: a template is
easy to read only while it stays a straightforward projection of the data. When it grows
nested conditionals, computed values, and business logic buried in {% %}, it becomes a
program written in the worst possible language, hard to test and hard to follow. The
healthy split is to keep the *thinking* in the data and in named intermediate variables
(enabled_services, effective_config, computed in the play where they can be seen and
tested), and let the template do only the *shaping* - loop, substitute, format. When a
template starts making decisions instead of presenting them, move the decision back into
the data.
