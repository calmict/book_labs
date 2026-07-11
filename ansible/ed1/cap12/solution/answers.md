# Chapter 12 — Answers (model solution)

## The completed TODOs

    # TODO 1 — the structured types in group_vars/web.yml
    features:
      - metrics
      - tracing
      - healthcheck
    limits:
      max_connections: 200
      timeout_seconds: 30

    # TODO 2 — the template lines in config.j2
    port = {{ port }}
    debug = {{ debug_mode }}
    features = {{ features | join(', ') }}
    max_connections = {{ limits.max_connections }}
    timeout = {{ limits.timeout_seconds }}
    log_level = {{ log_level | default('info') }}
    workers = {{ worker_count }}

    # TODO 3 — the derived variable in site.yml
    - name: Derive the worker count (2 per CPU)
      ansible.builtin.set_fact:
        worker_count: "{{ nproc_result.stdout | int * 2 }}"

solution/run.sh drives the whole chapter with an ephemeral venv and two nodes, and
guaranteed teardown: the five value types rendered, the host_vars port override
(web1 8080 vs web2 8081), the fact (hostname), the default (log_level=info), the
set_fact (workers = 2 x CPUs), the -e override (canary beats group_vars), and the acid
test (re-run -> changed=0).

## The three questions

**a. Types and quoting (chapter 4, again).**

debug_mode: false is parsed by YAML as a boolean, not the text "false", and when Jinja2
renders a Python boolean into a file it writes False (capital F) — Python's repr, not the
lowercase your config file probably expects. That is the chapter 4 trap wearing a new
hat: the values that YAML types *for* you — false, no, yes, on, off, and the Norway
country code NO — stop being the characters you wrote and become booleans, and only some
of them survive a round trip looking the way you meant. You reach for quotes exactly when
you need the *text*, not the type YAML would infer: version: "1.10" to keep the trailing
zero, mode: "0644" to keep the octal string, country: "NO" to keep Norway, and a literal
enabled: "true" if a downstream program wants the lowercase word rather than a boolean.
And when you have a real boolean but need it rendered a certain way, you fix it at the
point of use, not at the point of definition: {{ debug_mode | lower }} turns the rendered
False into false without changing the variable's type, so it still behaves as a boolean
in when: conditions elsewhere. Rule of thumb: let YAML type the things you compute with
(numbers, booleans, lists), quote the things that only look like types but are really
identifiers or formatted text, and shape the *rendering* with a filter rather than
lying about the *type*.

**b. register vs set_fact, and why derive instead of hardcode.**

register and set_fact both capture values at run time, but they answer different
questions. register attaches the *entire result object* of a task to a name — stdout,
stderr, rc, changed, and module-specific fields — so nproc_result holds not just the
number but the whole outcome, and you dig out what you need (nproc_result.stdout).
set_fact *defines a new variable* from an expression you write, evaluated on the host and
then available to every later task and template as if you had put it in group_vars. In
this lab they work as a pair: register grabs the raw CPU count off the node, set_fact
turns it into the derived worker_count = stdout | int * 2. Doing it with set_fact instead
of writing workers = 8 into group_vars is the difference between a config that *fits the
machine* and one that merely *asserts a number*. Hardcode 8 and the file is correct on a
4-CPU node by luck and wrong on every other size: an 8-CPU node is left running 8 workers
when it should run 16, a 2-CPU node is over-subscribed at 8. Deriving it means the same
playbook, unchanged, produces workers = 16 on the big node and workers = 4 on the small
one, because the value is computed from a fact of the node rather than a guess baked into
version control. The general lesson: prefer variables *derived from what the machine
tells you* over constants you have to remember to update per host.

**c. Where to define what, and who wins when two places disagree.**

Put a value where its *scope* lives. A setting true of every web server — app_name, the
feature list, the connection limits — belongs in group_vars/web.yml, defined once for the
group; a value true of a single host — web2's port — belongs in host_vars/web2.yml, so
the exception sits next to the host it describes and nowhere else; a value meaningful only
inside one play — config_dir — belongs in that play's vars:, not scattered into the
inventory; and a one-evening override — "just this run, call it canary" — belongs on the
command line with -e, precisely because it is temporary and leaves no trace in the files.
The guiding rule is the fewer places a given value is defined, the fewer surprises: one
obvious home per variable beats the same name sprinkled across three files. But the moment
the same name *is* set in two places that disagree — app_name in group_vars and app_name
on the -e line — something has to decide the winner, and here -e won: the command line
beat the group. That was not arbitrary. Ansible ranks every possible source of a variable
in a fixed order, from the weakest (role defaults) to the strongest (extra vars on the
command line), and when two sources define the same name the higher rank wins silently —
no error, the other value just loses. There are twenty-two of these ranks, with traps and
near-ties that catch people out, which is why resolving "why did *that* value win?"
deserves — and gets — an entire chapter of its own: chapter 13.
