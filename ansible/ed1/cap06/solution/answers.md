# Chapter 6 — Answers (model solution)

## The setup, at a glance

    bash solution/setup.sh          # venv + ansible-core, then version / family / ping
    bash start/nodes.sh up          # prepare cap06-web (2206) and cap06-db (2207)
    # ... work through the coming chapters ...
    bash start/nodes.sh down        # tear the nodes down
    rm -rf solution/.venv           # throw the isolated box away

solution/run.sh drives the whole arc (install, verify, ping, core-vs-package count,
node prep + SSH reachability) with an ephemeral venv and guaranteed teardown.

## The two completed pieces

requirements.txt (reproducible pin):

    ansible-core==2.15.13

setup.sh (the isolated install):

    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q -r requirements.txt
    "$VENV/bin/ansible" localhost -m ping     # -> pong

## The three questions

**a. Why a venv (or pipx) instead of the system Python.**

The system Python belongs to the operating system: distributions ship tools written
in Python and depend on specific versions of specific libraries being present there.
If you pip-install Ansible (and its dependency tree) into that system interpreter you
can upgrade or downgrade a shared library out from under those tools and break them —
the infamous way to render a package manager or a distro utility unusable. You also
get one global namespace for every project, so two projects that need different
Ansible versions cannot coexist, and there is no clean way to undo an install. A venv
(or pipx, which manages a venv per app for you) gives each project its own isolated
box with its own interpreter and packages: nothing you install leaks into the system
or into other projects, versions are pinned per project, and cleanup is "delete the
folder". Isolation turns "install Ansible" from a risky global mutation into a
consequence-free, reproducible, throwaway operation.

**b. ansible-core vs the ansible package.**

ansible-core is the engine: the executables (ansible, ansible-playbook, ...), the
connection and execution machinery, and exactly one bundled collection,
ansible.builtin (the ~70 essential modules: ping, copy, file, service, command,
apt/yum, template, and so on). The ansible package is a distribution that installs
core and then adds a large, curated set of community and vendor collections on top
(community.general, ansible.posix, cloud collections, network collections, ...) —
hundreds of extra modules. For these exercises core is enough because the labs use
the built-in modules, and a smaller install is faster, more stable, and easier to pin
and reason about. You would want the full bundle (or, better, install just the
specific collections you need with ansible-galaxy) when a task requires a module that
lives outside ansible.builtin — managing a cloud resource, a database, a network
device, or using a convenience module from community.general.

**c. Why localhost pinged with no inventory or SSH.**

localhost is a special, implicit host that Ansible always knows about: you do not have
to declare it in an inventory, and by default Ansible talks to it with the local
connection plugin instead of SSH, running the module directly in a subprocess on the
control node. So the ping succeeded because nothing about the network was involved —
no host to resolve, no key to present, no sshd to reach. To ping cap06-web instead,
two things are still missing, and they are the next two chapters. First an inventory
(chapter 8): a place where the name cap06-web is defined, with how to reach it — its
address, its SSH port, the user, the key. And the connection details that go with it
(where the ansible.cfg of chapter 7 sets defaults like the private key and host-key
checking). Only once Ansible knows that cap06-web exists and how to open an SSH
connection to it can the same ping travel the real journey of chapter 2 — control
node to managed node, over SSH, with the node's own Python.
