# Chapter 7 — Answers (model solution)

## The completed rulebook (the exercise's TODOs)

    [defaults]
    inventory = ./inventory.ini
    forks = 10
    host_key_checking = False        # lab only

    [privilege_escalation]
    become = True                    # lab convenience; see question c
    become_method = sudo

    [ssh_connection]
    pipelining = True

    # which file is active?          ansible --version | grep 'config file'
    # what differs from defaults?    ansible-config dump --only-changed
    # connection-plugin deltas too:  ansible-config dump --only-changed -t all

solution/run.sh drives the whole arc (hierarchy, dump, world-writable trap,
production cfg) with an ephemeral venv and guaranteed cleanup. Note that
solution/ansible.cfg — the production rulebook — deliberately differs from the lab
answers above: no host_key_checking, become = False.

## The three questions

**a. "forks = 50 in ~/.ansible.cfg does nothing".**

The hierarchy is not a merge: Ansible reads the FIRST file it finds — ANSIBLE_CONFIG,
then ./ansible.cfg, then ~/.ansible.cfg, then /etc/ansible/ansible.cfg — and uses it
outright. Since the project folder has its own ansible.cfg, the home file is never
opened at all: the colleague's forks = 50 is not "overridden", it is simply never
read. The one-command proof is:

    ansible --version | grep 'config file'

which names the active file (it will point at the project's ansible.cfg). Or richer:
ansible-config dump --only-changed, where every changed value carries the path of the
file it came from — forks will show the project path, not the home one. The fix is to
set forks where it counts: in the project cfg, or ANSIBLE_CONFIG for an explicit
override.

**b. Why ignore, not just warn.**

Because a warning does not stop the attack — by the time you read it, the poisoned
configuration would already be loaded. The cwd cfg is the one place in the hierarchy
that OTHER people can control: on a shared machine, anyone who can write to a
directory you might cd into can plant an ansible.cfg there. And that file is not mere
tuning — it decides what gets executed: inventory (which hosts you talk to, so your
deploy could be redirected to the attacker's machine to harvest secrets and
credentials), plugin/module/roles paths (arbitrary Python loaded and run on YOUR
control node, with your keys and your privileges), callback plugins (exfiltrating
everything each run produces), become settings. Loading such a file from a
world-writable directory would hand the control node to whoever got there first;
refusing to load it closes the hole entirely, at the small cost of the legitimate
owner having to fix the directory permissions.

**c. Silent defaults: host_key_checking = False and become = True.**

host_key_checking = False as a project default silently removes chapter 3's
man-in-the-middle defense for EVERY connection the project ever makes: a redirected
DNS name or a swapped host is accepted without a whisper, and nobody re-reads the cfg
before each run. The risk is invisible trust: production credentials typed into an
impostor. Better: keep the default True in production, seed known_hosts (or use
accept-new) — and if a lab really needs False, put it in the lab's inventory or
environment, where its scope is obvious.

become = True as a default makes every task of every play run privileged, whether it
needs it or not: a mistake in a template or a path now executes as root, and the
blast radius of any bug is maximal. It also hides intent — reading a play no longer
tells you whether it needs privilege. Better: become = False in the cfg (or omit it)
and declare become: true on the play or task that genuinely needs it, where the
reviewer can see it and question it. In both cases the principle is the same: the cfg
is the place for team-wide mechanics (inventory, forks, pipelining); anything that
weakens security or raises privilege should be declared close to where it is used,
visibly, not inherited silently from a file nobody looks at.
