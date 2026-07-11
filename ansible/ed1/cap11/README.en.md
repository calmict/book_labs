# Chapter 11 — The caretaker's keys

**Level:** Intermediate

In chapter 10 privilege was a switch flipped in bulk: become: true, and everything ran
as root. Now you open that box. **become** is not "just be root": it is asking the
building's **caretaker** for the keys — on Linux, almost always **sudo**. The caretaker
has a rulebook (the **sudoers** file): it decides *who* may take *which* key, and whether
they must first show ID (the **password**). This chapter — the first of the Intermediate
tier — shows you the anatomy of become, the rulebook under the hood, the three answers to
the password, how to become a user *other* than root, and the golden rules for not
leaving the master key lying around.

## Objectives

- Why **not** to log in directly as root (11.1).
- The **anatomy of become**: become, become_method, become_user, become_flags (11.2).
- **sudoers under the hood**: the gate that decides who becomes whom (11.3).
- The **sudo password**: -K, the variable (to be encrypted), NOPASSWD (11.4).
- **Not only sudo**: the other methods (11.5).
- **Becoming a user other than root** (11.6).
- The **golden rules** of security (11.7).

## Prerequisites

- The chapter 6 venv (or start/requirements.txt).
- Docker for two nodes. Network on first boot.
- The become: true of chapter 10; the inventory of chapter 8.

## The scenario

Two nodes, two caretaker policies. **web1** you reach as **deploy**, who holds a standing
pass (NOPASSWD): it escalates without showing anything. **web2** you reach as **secops**,
who may escalate but **must show the password** every time. Both nodes carry **appsvc**, a
service account: we will become *it*, not root, to write its files.

## Step by step

### Phase 0 — Power the nodes on

    bash start/nodes.sh up

Two containers. web1 with the deploy user (NOPASSWD), web2 with secops (password), both
with appsvc and with the **acl** package (needed in Phase 5).

### Phase 1 — Why not log in as root, and the anatomy of become

You could connect directly as root and be done. You don't, for three reasons: **audit**
(the logs read "deploy ran sudo X", not an anonymous "root did X"); **least privilege**
(you stay an ordinary user and rise only for the actions that require it); **attack
surface** (root's SSH login is disabled, so a stolen key is not instantly the master
key). Ansible does exactly this: it connects as an ordinary user and **rises in rank only
when needed**. The knobs:

- **become**: true/false — do I ask for the keys or not.
- **become_method**: how I ask (sudo by default).
- **become_user**: who I become (root by default).
- **become_flags**: fine options passed to the method.

### Phase 2 — Turn on become and see who you become (TODO 1)

Open start/site.yml. Complete **TODO 1**: turn on become: true for the play. Then the
first task asks the node who you really are:

    - name: Confirm we escalated to root
      ansible.builtin.command: id -un
      register: who
      changed_when: false

    - name: Show who connected and who we became
      ansible.builtin.debug:
        msg: "{{ ansible_user }} -> {{ who.stdout }}"

Run it and read the debug:

    "msg": "deploy -> root"
    "msg": "secops -> root"

Two different users connected, both rose to root. *How* they rose, though, differed —
which is the next phase.

### Phase 3 — The caretaker's rulebook: sudoers

Who decides whether deploy and secops *may* rise? The **sudoers** file on the node. Read
the two policies:

    cat /etc/sudoers.d/deploy      # deploy ALL=(ALL) NOPASSWD:ALL
    cat /etc/sudoers.d/secops      # secops ALL=(ALL) ALL

Read them as: **user  hosts=(target-users)  commands**. deploy may become anyone (ALL)
and run any command (ALL) **without a password** (NOPASSWD). secops has the same rights
**but without NOPASSWD**: it must show ID. sudoers is the gate: without a line here,
become fails — no key will help. (Note: you edit it with visudo, which validates the
syntax; a broken line can lock you out.)

### Phase 4 — The sudo password (TODO 2)

web2 (secops) requires a password. Try running without giving it:

    ansible-playbook -i start/inventory.ini -l web2 start/site.yml

    fatal: [web2]: FAILED! => {"msg": "Missing sudo password"}

The caretaker stopped you at the gate. There are **three** answers:

1. **-K** (--ask-become-pass): Ansible prompts you at launch, interactively. Great at a
   terminal, useless in automation (no one is typing).
2. The **variable** ansible_become_password: you write it in the inventory. Convenient
   for automation, but it is a **plaintext password** — it must be **encrypted with
   Vault** (chapter 18). Here, for the lab, we leave it in the clear with this warning.
3. **NOPASSWD**: no password (deploy's case). Very convenient, but also the weak point —
   Question b.

Complete **TODO 2** in start/inventory.ini: give web2 its ansible_become_password. Re-run:
now secops clears the gate too.

### Phase 5 — Becoming a user other than root (TODO 3)

become does not mean only "root". Often you want to become the **service account** — here
appsvc — to create *its* files with *its* ownership, without going through root and then
fixing up. Complete **TODO 3**: add become_user: appsvc to the task that writes the
marker:

    - name: Write the ownership marker AS the app user, not root
      ansible.builtin.copy:
        content: "owned by the service account, not root\n"
        dest: /srv/app/owner.txt
        mode: "0640"
      become_user: appsvc

The play rises to root (become: true), but **this task** drops to appsvc. Verify:

    stat -c '%U:%G' /srv/app/owner.txt      # -> appsvc:appsvc, not root

**Mind a real gotcha:** becoming an *unprivileged* user (root → appsvc) forces Ansible to
hand it the temporary files, and to do that it uses **ACLs** (setfacl). If the node lacks
the acl package, it fails with "Failed to set permissions on the temporary files…". That
is why start/nodes.sh installs acl. It is one of the few requirements Ansible imposes *on
the nodes*.

### Phase 6 — Not only sudo

sudo is the caretaker of 99% of Linux systems, but not the only one. Changing
become_method calls on other doormen:

- **su** (the elder, asks for the *target's* password), **doas** (OpenBSD's minimalist),
  **pbrun**/**pfexec** (enterprise/Solaris worlds), **runas** (Windows).

With become_exe and become_flags you tune the executable and its options. But without a
specific reason, stay on sudo: it is the one the nodes already know.

### Phase 7 — The golden rules

- **Least privilege**: become where it is needed, not "on everywhere for convenience". A
  task that does not touch root should not rise.
- **Narrow NOPASSWD**: if you automate without a password, do not grant ALL — list the
  **specific commands** in sudoers (Question b).
- **No direct root login**: come in as a user, rise with become; disable root over SSH.
- **The password in Vault**: never in plaintext in versioned files (chapter 18).
- **Targeted become_user**: become the right user for the action, not root for
  everything.

## Done when

- With become: true, the debug shows **deploy -> root** and **secops -> root**.
- web2 **without** ansible_become_password → "Missing sudo password"; **with** the
  variable → it passes.
- /srv/app/owner.txt is owned by **appsvc**, not root; the /srv/app directory is appsvc's.
- Re-running → **changed=0** (idempotence).

## Questions to reflect on

**a.** Why is it better to connect as an ordinary user and *escalate* with become, rather
than logging in directly as root? List at least three concrete advantages (think about:
who shows up in the logs, what happens if the key is stolen, what you can disable on SSH).

**b.** NOPASSWD is convenient — automation has nothing to type — but ALL=(ALL)
NOPASSWD:ALL is a master key with no lock. Why is it dangerous, and how would you keep
automation *passwordless* while narrowing what it can do? And if you choose to use the
password instead, where is the right place to keep it (a preview of ch. 18)?

**c.** The marker is written with become_user: appsvc, not as root. Why is creating a file
*as* the service account better than creating it as root and then chown-ing it? (Think
about correct ownership from the start, least privilege, and what can go wrong in "I'll
fix it afterwards".)

## Cleanup

    bash start/nodes.sh down

## Where it leads

You met your first "serious" variable: ansible_become_password. Chapter 12 opens that
world in full — **the meticulous management of variables**: where they live (play,
inventory, command line), the types, Jinja2, register and set_fact. And the password you
left in plaintext here will find its safe at chapter 18, with Ansible Vault.
