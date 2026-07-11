# Chapter 17 — Answers (model solution)

## The completed TODOs

    # TODO 1 — requirements.yml (the collection, pinned)
    collections:
      - name: community.general
        version: "8.6.0"

    # TODO 2 — ansible.cfg (keep collections in the project)
    [defaults]
    collections_path = ./collections

    # TODO 3 — site.yml (the collection module, by FQCN)
    - name: Manage an INI key with a collection module
      community.general.ini_file:
        path: "{{ conf_path }}"
        section: server
        option: port
        value: "8080"
        mode: "0644"

solution/run.sh installs the pinned collection into a project-local collections/ folder,
confirms the exact version, and runs the playbook: a community.general module (called by
FQCN) writes the INI next to the ansible.builtin modules, idempotently (re-run ->
changed=0). No managed nodes; guaranteed teardown of the ephemeral venv.

## The three questions

**a. Why the full name community.general.ini_file, not just ini_file.**

Because the short name is ambiguous and the full name is not. A module's real identity is
namespace.collection.module — community.general.ini_file — and the FQCN states all three
parts, so there is exactly one module it can mean. Short names only work because Ansible
keeps a search path of collections and picks the first match, which is fine until two
collections on that path both ship a module called ini_file: now "ini_file" resolves to
whichever collection happens to come first in the search order, silently, and the same
playbook can run different code on two machines whose collection sets differ, or break the
day you add a collection that shadows the name. Writing the FQCN removes the guesswork:
community.general.ini_file is that collection's module and no other, regardless of what
else is installed or in what order. It also makes the playbook self-documenting — a reader
sees immediately where each module comes from, which matters when some are built in and
some are third-party — and it is why ansible.builtin.copy has been spelled out in full all
along: builtin is just another collection, and being explicit about it is the same good
habit. In serious playbooks, always the FQCN; the short form is a convenience for the
command line, not a foundation to build on.

**b. Why keep collections in the project, pinned, instead of globally in ~/.ansible.**

Because a project that depends on code it does not control should control *which version*
of that code it runs, and where. Installed globally in ~/.ansible/collections, a collection
is shared across every project on the machine and sits at whatever version was last
installed — so the playbook's behaviour depends on the machine's history, not on the
project, and "works on my laptop" becomes a real sentence: your community.general is 8.6.0,
a colleague's is 9.x with a changed module, and the same playbook does different things with
no diff to explain it. Pinning the version in requirements.yml and pointing collections_path
at a folder inside the project fixes both halves: requirements.yml records exactly which
versions this project was written against, and collections_path puts them somewhere tied to
the project rather than to the user account, so ansible-galaxy install reproduces the same
set for anyone who clones the repo. It is the same idea as chapter 7's lock file for tofu:
declare the dependency and freeze its version, so the environment is reproducible instead of
"whatever happened to be there". You do not commit the downloaded collection itself — it is
regenerated from requirements.yml, exactly as you do not commit downloaded packages — but
you commit the requirements.yml and the config that say precisely what to fetch. Declared,
pinned, and local beats implicit, floating, and global.

**c. Why not run a random third-party role, and what to check first.**

Because installing a collection or role means bringing someone else's code into your
automation, and your automation runs with your privileges — often become, i.e. as root, on
every host in your inventory (chapter 11). A malicious or merely careless third-party role
executed that way can do anything root can do, everywhere you point Ansible: exfiltrate
secrets, open backdoors, wreck the fleet — and it does so with the trust and reach you have
spent the whole book building. So "found a role that does X, let's run it" is exactly the
wrong instinct. Before you give third-party content your privileges, check what it is and
where it comes from: prefer collections from a namespace you trust (ansible.*, well-known
community.* collections, or your organisation's certified content on Automation Hub) over an
unknown author's one-off; pin a specific reviewed version rather than "latest", so an
upstream account compromise or a surprise release cannot silently change what you run; read
the tasks — a role is just YAML, you can open it and see whether it does what it claims and
nothing else, paying attention to command/shell tasks, downloads, and anything touching
credentials; and when in doubt, run it first without become, or against a throwaway host, and
watch. The convenience of standing on giants is real, but you are handing them root — so
verify the giant before you climb on.
