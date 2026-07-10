# Chapter 8 — Answers (model solution)

## The completed address book (the TODOs)

    [web]
    web1 ansible_port=2281
    web2 ansible_port=2282

    [prod:children]
    web
    db

    # group_vars/web.yml
    http_port: 8080
    greeting: hello from the web section

    # verify the tree, the patterns, and the roll:
    ansible-inventory -i inventory.ini --graph
    ansible -i inventory.ini 'web:!web2' --list-hosts
    ansible -i inventory.ini prod -m ping

solution/run.sh drives the whole arc (graph, patterns, YAML == INI, group_vars, the
ping) with an ephemeral venv and nodes, and guaranteed teardown. inventory.yml is the
same address book in YAML, to compare with the INI.

## The three questions

**a. INI vs YAML.**

They express the same thing; the choice is about shape and audience. INI is terser
and reads at a glance for the common case — a few groups, a host per line, a variable
or two — which is why small inventories are pleasant in INI. It gets awkward when the
data is deep or structured: a host variable that is itself a list or a dictionary
does not fit "key=value on the host line", and nested group variables become
cramped. YAML is more verbose for the simple case (more punctuation, more nesting)
but it represents structure natively — lists, maps, multi-line values — so it wins
for rich per-host/per-group data, and it is the format other tooling (and dynamic
inventories) speaks. A rule of thumb: reach for INI while the inventory is a plain
list of hosts and groups; switch to YAML when variables stop being flat scalars, or
when the same file must interoperate with code that expects YAML. And whichever you
pick, remember chapter 4: in YAML you must quote the values that would be mistyped.

**b. Why groups, not hosts.**

Because the group is a stable name for an intent ("the web servers"), while the list
of hosts behind it changes constantly. Targeting the group decouples what you want to
do from who currently happens to be in the fleet: the command ansible web -m ... is
written once and stays correct as web1,web2 becomes web1..web50. Going from 3 to 300
hosts, ansible web1,web2 would have to be found and edited everywhere it appears —
playbooks, cron jobs, runbooks, muscle memory — and every place you missed silently
skips the new servers; ansible web just works, because the inventory is the single
place that maps the name to the members. Groups are also how variables, patterns, and
later roles attach to a set rather than to individuals, so "web" carries not just
membership but the configuration and behaviour that go with being a web server. Names
that describe role, not identity, are what let the fleet grow without the automation
rotting.

**c. group_vars vs scattered variables; the new problem.**

The directory scales best for three reasons. It separates identity from
configuration: the inventory stays a clean map of who-and-where, while group_vars/ and
host_vars/ hold what-they-are, so neither file becomes a wall of mixed concerns. It is
discoverable and diff-friendly: to know a group's settings you open one predictably
named file (group_vars/web.yml), and a change is a small, reviewable diff instead of
an edit buried in an inventory line. And it grows without touching the inventory: add
a variable for the whole group by editing one file, not every host line. The new
problem it introduces is precedence: the same variable can now be set in several
places — the host line, [group:vars], group_vars/, host_vars/, the command line,
the play — and when two of them disagree, you must know which one wins. A value set in
two files that quietly conflict is harder to debug than a single obvious definition,
because nothing errors; the "wrong" one just loses silently. Ansible resolves this
with a fixed, 22-level precedence order — which is exactly what chapter 13 is about.
