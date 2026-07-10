# Chapter 7 — The nearest music stand

**Level:** Foundational

The conductor has the baton (chapter 6); now comes the **orchestra rulebook**:
ansible.cfg, the file where the rules of how Ansible works live — how many players
in parallel, which key to enter with, whether to ask for permission. The most
important thing to understand is not *what* is written in it, but **which copy of
the rulebook gets read**: Ansible looks at four music stands in a fixed order and
uses **the first one it finds, in its entirety** — no merging. And there is a
security trap: if the stand is in a room anyone can write in, Ansible **refuses to
read it**.

## Objectives

- The **search hierarchy**: ANSIBLE_CONFIG → ./ansible.cfg → ~/.ansible.cfg →
  /etc/ansible/ansible.cfg; the first one found **wins outright** (no merging).
- The file structure and the **[defaults]** section (inventory, forks,
  host_key_checking).
- **[privilege_escalation]** (become) and **[ssh_connection]** (pipelining —
  chapter 3's ControlMaster becomes a setting).
- The **ansible-config** tools: list, view, and the precious
  **dump --only-changed**.
- The **trap** of the world-writable directory: the cwd cfg is convenient and
  dangerous.

## Prerequisites

- The chapter 6 venv with ansible-core (or rebuild it: python3 -m venv .venv and
  pip install -r start/requirements.txt).
- No containers: this chapter is all configuration and inspection.

## Step by step

### Phase 1 — Which rulebook is it reading?

Ask it — the answer is on the first screen:

    ansible --version | grep 'config file'

If you have no cfg of your own, you will see the system one
(/etc/ansible/ansible.cfg) or None. Now move into the exercise folder, where
start/ansible.cfg lives, and ask again:

    cd start/
    ansible --version | grep 'config file'

Now it reads **./ansible.cfg**: the nearest stand. The full order, strongest
first:

1. **ANSIBLE_CONFIG** (environment variable) — the explicit order
2. **./ansible.cfg** — the current directory (the project)
3. **~/.ansible.cfg** — your home
4. **/etc/ansible/ansible.cfg** — the system

Try it with the variable:

    ANSIBLE_CONFIG=/tmp/other.cfg ansible --version | grep 'config file'

The golden rule: **the first one found wins outright**. If the project cfg forgets
a line that existed in the system one, that line *no longer exists* — it is not
inherited.

### Phase 2 — TODO 1: the [defaults] section

Open start/ansible.cfg: the structure is INI (sections in square brackets).
Complete **TODO 1** in the [defaults] section:

    [defaults]
    inventory = ./inventory.ini
    forks = 10
    host_key_checking = False

- **inventory**: where the address book lives (chapter 8) — so you stop passing it
  to every command;
- **forks**: how many hosts in parallel (chapter 1's "three, thirty, three
  thousand" — the default is only 5);
- **host_key_checking**: you know it from chapter 3 — False in the lab, never in
  production.

### Phase 3 — The tools: ansible-config

Three commands so you never work blind:

    ansible-config list             # ALL possible settings, documented
    ansible-config view             # the active file, as it is
    ansible-config dump --only-changed

The last one is the gem: it shows **only what differs from the defaults**, and for
each value **which file** it comes from. It is the answer to "but which rule is it
actually using?":

    DEFAULT_FORKS(/path/ansible.cfg) = 10
    HOST_KEY_CHECKING(/path/ansible.cfg) = False

### Phase 4 — TODO 2: privileges and speed

Complete the other two sections:

    [privilege_escalation]
    become = True
    become_method = sudo

    [ssh_connection]
    pipelining = True

- **become**: asking for administrator rank (chapter 11 goes deep); here you learn
  that the *default* for this behaviour lives in the cfg;
- **pipelining**: fewer SSH round-trips per task — the sibling of chapter 3's
  ControlMaster; chapter 25 will measure what it is worth.

Verify with dump --only-changed: DEFAULT_BECOME appears. And pipelining? It is not
there — because it is a *connection plugin* setting, not a core one. The base dump
shows core only; to see the connection plugins too:

    ansible-config dump --only-changed -t all

Now pipelining(...) = True appears as well. A small but precious detail: when "I
set it but it is not in the dump", try -t all before blaming the file.

### Phase 5 — The trap: the stand in the open room

The cfg in the current directory is convenient — and dangerous for the same
reason: if you work in a directory where **anyone can write**, another user could
plant a poisoned ansible.cfg there (say, their own inventory or a malicious plugin
path), and you would execute it unknowingly. Ansible knows, and defends itself:

    mkdir -p /tmp/open-room && chmod 777 /tmp/open-room
    cp ansible.cfg /tmp/open-room/
    cd /tmp/open-room && ansible --version

    [WARNING]: Ansible is being run in a world writable directory ...
    config file = /etc/ansible/ansible.cfg

Your cfg is right there, but Ansible **ignores it** and falls back to the system
stand. It is not a whim: it is the same philosophy as the private key permissions
(chapter 3) — a file that decides *what gets executed* must be writable only by its
owner.

### Phase 6 — The production rulebook

Read solution/ansible.cfg: it is a **production cfg commented line by line** —
what to keep, what never to set (host_key_checking = False stays lab material), and
why each value. It is the manual's 7.5 in executable form.

## Done when

- You can say **which** cfg is active and why (the four stands in order).
- start/ansible.cfg completed: dump --only-changed shows **forks,
  host_key_checking, become, pipelining** with your file's path.
- You saw the **trap**: in the world-writable directory the cfg is ignored with the
  WARNING.
- You can explain why the hierarchy **does not merge** files, and what that
  implies.

## Questions to reflect on

**a.** A colleague says: "I set forks = 50 in ~/.ansible.cfg but nothing changes".
There is an ansible.cfg in the project folder. Explain to them what is happening
and how to verify it in one command.

**b.** Why does Ansible ignore the cfg in a world-writable directory instead of
just warning? What could an attacker do with a poisoned ansible.cfg?

**c.** host_key_checking = False and become = True in the project cfg: convenient
in the lab, risky in production. For each, say *which* risk it introduces as a
**silent default** and where you would rather declare it instead of the cfg.

## Cleanup

    rm -rf /tmp/open-room

## Where it leads

The rulebook is there, but it says inventory = ./inventory.ini — a file that does
not exist yet. In chapter 8 you write the **address book** (the inventory): names,
groups and addresses of the players. In 9, the first real order over SSH.
