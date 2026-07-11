# Chapter 11 — Answers (model solution)

## The completed TODOs

    # TODO 1 — turn on escalation for the play (site.yml)
    - name: Privilege escalation in depth
      hosts: all
      become: true

    # TODO 2 — give the password-required host its become password (inventory.ini)
    web2 ansible_port=2322 ansible_user=secops ansible_become_password=secops-pw

    # TODO 3 — drop from root to the service account for this task (site.yml)
    - name: Write the ownership marker AS the app user, not root
      ansible.builtin.copy:
        content: "owned by the service account, not root\n"
        dest: /srv/app/owner.txt
        mode: "0640"
      become_user: appsvc

solution/run.sh drives the whole chapter with an ephemeral venv and two nodes, and
guaranteed teardown: the two sudoers policies, the password gate (web2 without the
password fails with "Missing sudo password"), the full run (deploy -> root,
secops -> root, the marker owned by appsvc), and the acid test (re-run -> changed=0).

## The three questions

**a. Why connect as an ordinary user and escalate, instead of logging in as root.**

Three concrete wins, all about limiting blast radius and keeping a record. First,
accountability: when everyone connects as their own account and escalates with sudo,
the node's logs read "deploy ran sudo X", "secops ran sudo Y" — a named, auditable
trail — whereas a direct root login is an anonymous "root did it", indistinguishable
between people and tools. Second, least privilege in daily use: you spend almost all
your time as an unprivileged user, holding root only for the specific tasks that need
it (and, with task-level become, only for those tasks), so a mistake or a runaway
command is contained instead of running with full power by default. Third, attack
surface: with escalation you can disable direct root login over SSH entirely
(PermitRootLogin no), which means a stolen or brute-forced credential lands you as an
ordinary user who still has to pass the sudoers gate — one lock became two. A root SSH
login collapses all three: no attribution, maximum standing privilege, and a single
secret that is game-over if leaked. The whole point of become is that the master key
lives with the caretaker (sudo) and is lent per the rulebook, not carried in your
pocket all day.

**b. Why ALL=(ALL) NOPASSWD:ALL is dangerous, and how to keep passwordless automation safe.**

NOPASSWD is convenient precisely because automation cannot type a password at a prompt
— but ALL=(ALL) NOPASSWD:ALL hands that account an unconditional master key: it may
become anyone and run anything, with no second factor and no record of intent. If that
account (or its SSH key) is compromised, the attacker inherits unrestricted root on
every node it can reach; the "no password" that helped your robot helps theirs just as
much. The fix is not to abandon passwordless automation but to *narrow the grant*:
instead of NOPASSWD:ALL, list the exact commands the automation is allowed to run
passwordless, e.g. deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart myapp,
/usr/bin/apt-get update — so a stolen key can restart your app but cannot add a user or
open a root shell. You keep the convenience (no prompt) while collapsing what that
convenience can do. If instead you decide the account *should* supply a password, then
the right home for that password is not the plaintext inventory line we used for the
lab but an encrypted store — Ansible Vault (chapter 18) — so the secret is versioned
safely and decrypted only at run time. Passwordless-but-narrow, or password-but-
encrypted: either is defensible; broad-and-passwordless is the one to avoid.

**c. Why write the file AS appsvc rather than as root and then chown.**

Because "create as root, then chown to appsvc" has a window and a failure mode that
"create as appsvc" does not. In the two-step version the file exists, however briefly,
owned by root with root's default permissions before the chown lands — and if the play
stops between the two steps (an error, a connection drop, someone hitting Ctrl-C), you
are left with a file the service account cannot read or write, a subtle breakage that
surfaces later as "the app can't open its own file". Doing it in one step with
become_user: appsvc means the file is created by the right owner from the first instant;
there is no interval of wrong ownership and no second task that can fail independently.
It is also least privilege applied to *writing*: the bytes are produced by the account
that will own them, not by root reaching down, so nothing runs with more power than the
job needs. The cost is the one wrinkle this chapter surfaced: becoming an unprivileged
user makes Ansible hand the temporary files across accounts, which needs ACL support
(the acl package) on the node — a small, one-time node requirement in exchange for
correct ownership and no chown-shaped race.
