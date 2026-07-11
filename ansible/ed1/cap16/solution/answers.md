# Chapter 16 — Answers (model solution)

## The completed TODOs

    # TODO 1 — roles/webapp/defaults/main.yml (the knobs, level 2)
    app_name: myapp
    port: 8080
    features:
      - logs
      - cache

    # TODO 2 — roles/webapp/tasks/main.yml (bare src, notify the handler)
    - name: Render the config
      ansible.builtin.template:
        src: app.conf.j2
        dest: "{{ config_dir }}/app.conf"
        mode: "0644"
      notify: reload webapp

    # TODO 3 — site.yml (the three-line playbook)
    roles:
      - webapp

solution/run.sh shows the galaxy-init skeleton, runs the role, and checks: app_name =
webfromgroup (group_vars beat the default), config_dir = /etc/webapp (the role's vars beat
group_vars, /etc/WRONG never created), app.conf and motd resolved from the role's own
folders, the handler firing once, and a clean re-run (changed=0). Guaranteed teardown.

## The three questions

**a. Why app_name goes in defaults and config_dir in vars.**

Because the two directories sit at opposite ends of the precedence scale, and that is
exactly what makes a role reusable. defaults is level 2, almost the weakest thing there is:
anything a user might set — an inventory line, a group_vars file, a play var, a -e on the
command line — beats it. So defaults is the role's *public interface*, the set of knobs the
role invites you to turn: app_name, port, features are values every consumer will want to
customise, and putting them in defaults means "here are the dials, override any of them
however you like". vars is level 15, high up: it beats the inventory, group_vars, host_vars
and play vars, so it is *not* casually overridable. That is where the role's internal gears
belong — config_dir is an implementation detail the role relies on to place its files, not
something a random group_vars should be able to move out from under it. The lab proves both:
group_vars sets app_name and the default yields (webfromgroup wins), while group_vars also
sets config_dir and the role's vars refuses (/etc/webapp wins, /etc/WRONG is never used).
Get it backwards and the role breaks in two ways. Put config_dir in defaults and any stray
group_vars silently relocates the role's files, scattering config where the tasks do not
expect it — a fragile role. Put app_name in vars and you have taken away the very knob users
need: no inventory or play can rename the app, so the role is rigid, "reusable" only if you
never wanted it to differ. defaults for what should change, vars for what must not: that is
the heart of a role that travels well.

**b. How src: app.conf.j2 resolves, and why it makes a role portable.**

Inside a role, the file-shipping modules know where to look: template searches the role's
templates/ directory, copy searches its files/ directory, and lookups fall back through the
role's structure. So src: app.conf.j2 with no path is resolved to
roles/webapp/templates/app.conf.j2 automatically, and src: motd to
roles/webapp/files/motd. The point is that the reference is *relative to the role, not to
the machine*. A role is meant to be moved — copied into another project, published to
Galaxy, cloned onto a colleague's laptop, checked out at a different path in CI — and a bare
filename survives all of that because it means "my own templates/app.conf.j2", wherever
"my" happens to live. An absolute path like /home/me/ansible/roles/webapp/templates/... would
nail the role to one directory on one machine: move it and every template task breaks, and
the role stops being a self-contained unit and becomes a thing that only works in the exact
tree it was born in. Auto-resolution is what lets a role be a portable package rather than a
set of file references into a particular filesystem — the same property that lets you say
roles: - webapp and have it just work no matter where the role sits.

**c. import_role (static) vs include_role (dynamic).**

The difference is *when* the role is brought in. import_role is static: Ansible expands it
while it is parsing the playbook, before execution begins, splicing the role's tasks into
the play as if you had written them there. include_role is dynamic: Ansible resolves it at
run time, when execution actually reaches that line. For a plain "always run this role"
either works and import_role is a touch more efficient and gives you the full task list up
front (handy for --list-tasks). The distinction bites the moment the *decision* to include,
or *which* role, or *how many times*, depends on something known only at run time. You
cannot import_role inside a loop to run a role once per item, because static expansion
happens before the loop's values exist — include_role can, resolving fresh on each
iteration. Likewise a when on an import_role does not gate the include itself (it is applied
to each imported task after the fact), whereas include_role under a when that depends on a
registered result or a set_fact is evaluated at run time and genuinely skips the whole role
when false. And a role name built from a variable — include_role: name: "{{ chosen_role }}"
— only works dynamically, since the name is not known at parse time. So: import_role when
the inclusion is fixed and you want it resolved statically; include_role when the inclusion
is conditional on runtime state, driven by a loop, or chosen by a variable.
