# Chapter 19 — The strongroom

**Level:** Advanced

In chapter 18 you shut the password in the strongbox. But a paradox remained: the strongbox
is encrypted, and its key — the vault passphrase — where does it live? If you write it in a
file next to the playbook, you are back at chapter 11's sin: a secret in clear on disk.
Chapter 18 moved the problem, it did not remove it. The real solution changes paradigm: the
secret is **not kept at all** — neither in clear nor encrypted — but **fetched at runtime**
from an external service that guards it, hands it to whoever has the right, and never lets it
rest with you. That service is a **strongroom**: in this lab, HashiCorp Vault.

## Objectives

- The **three limits** Vault (ch. 18) does not solve (19.1).
- The paradigm shift: the **runtime lookup** (19.2).
- **HashiCorp Vault** and the community.hashi_vault collection (19.3).
- **Authentication**: token, AppRole and machine identity (19.4).
- The **cloud secret managers**: AWS, Azure, GCP (19.5).
- **SSH keys** in production: distribution, rotation, bastion (19.6).
- **no_log**: the secret that must not end up in logs (19.7).
- When **Vault is enough** (ch. 18), when you need a **manager** (19.8).

## Prerequisites

- The chapter 6 venv (or start/requirements.txt), plus the hvac library.
- The community.hashi_vault collection (you install it, as in chapter 17).
- Docker: two containers run here — the secops node (as in ch. 18) and the strongroom.
- The secret is the same as ever: secops' sudo password. Only *where it lives* changes.

## The scenario

Two containers. The first, cap19-web1, is the usual node reached as **secops** (sudo with a
password). The second, cap19-vault, is **HashiCorp Vault** in dev mode: the strongroom. The
sudo password no longer sits in a file — neither in clear (ch. 11) nor encrypted (ch. 18): it
sits *inside the strongroom*. When needed, Ansible knocks, identifies itself, receives the
secret in memory for the length of a task, and becomes root. On disk, in the repository, in
the output: **nothing**.

The nodes.sh script prepares everything: it starts the node, starts the strongroom, deposits
the secret, and configures a machine identity (AppRole). In reality someone populates the
vault out of band; here the script does it for you — so nodes.sh is the only file that knows
the value, while the real configuration (group_vars, site.yml) never touches it.

## Step by step

Prepare the environment and the platform:

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    cd start
    ./nodes.sh up          # node + strongroom + secret deposited + AppRole ready

The script prints the strongroom address and the lab root token. Export them:

    export VAULT_ADDR=http://127.0.0.1:8200
    export VAULT_TOKEN=lab-root-token

### Phase 1 — The three limits that remain (19.1)

Vault (ch. 18) encrypts beautifully, but does not solve three things:

1. **The vault key is still a secret on disk.** You put it in a file or type it by hand: the
   first is in clear, the second cannot be automated.
2. **There is no access control and no revocation.** Whoever has the passphrase has
   *everything*, forever; you cannot give one person dev but not prod, nor take away access
   without re-encrypting everything.
3. **There is no audit and no easy rotation.** Vault does not know *who* decrypted *what*, and
   rotating a secret means editing files and re-committing.

A **secret manager** exists for these three gaps — Question a.

### Phase 2 — The paradigm shift: the runtime lookup (19.2 — TODO 1 and TODO 2)

So far the secret *travelled with the code* (in clear or encrypted). The paradigm flips: the
secret **stays in the strongroom**, and the playbook goes to **fetch it when needed**, with a
lookup.

First get the tool (as in chapter 17). Complete **TODO 1**: declare the collection in
requirements.yml —

    collections:
      - name: community.hashi_vault
        version: "7.1.0"

and install it (hvac is already in requirements.txt):

    ansible-galaxy collection install -r requirements.yml

Then the heart. Complete **TODO 2** in group_vars/web/vars.yml: the become password is no
longer a value, it is a *call to the strongroom* (next to it you already have, as a model,
the same lookup for app_db_password) —

    ansible_become_password: "{{ lookup('community.hashi_vault.hashi_vault',
        'secret/data/myapp:become_password',
        url=vault_url, token=vault_token) }}"

No encrypted file, no vault passphrase: the secret is read from the strongroom *at the
instant* it is needed, and lives only in memory for the length of the play. Compare the three
worlds — Question b:

    ch. 11:  ansible_become_password: secops-pw                          # clear on disk
    ch. 18:  ansible_become_password: "{{ vault_become_password }}"      # encrypted on disk
    ch. 19:  ansible_become_password: "{{ lookup('...hashi_vault'...) }}"  # not on disk

### Phase 3 — Running: the secret never touches disk (19.3)

Run:

    ansible-playbook -i inventory.ini site.yml

The play queries the strongroom, gets the password, becomes root, writes the marker. Then
look for the secret where the playbook might have left it — and you do not find it:

    grep -r secops-pw group_vars site.yml       # nothing in the configuration
    ansible-playbook -i inventory.ini site.yml -vvv | grep secops-pw   # nothing in the output

The secret existed only in RAM, for the length of a task. This is the strongroom (19.3): the
service guards, Ansible requests over the API (community.hashi_vault), the value settles
nowhere. (The only file that knows the value is nodes.sh, which simulates the out-of-band
deposit; the configuration that would go to production does not contain it.)

### Phase 4 — Who are you, to the strongroom? (19.4)

The strongroom does not hand out to anyone who knocks: first you **identify**. In TODO 2 you
used a **token** (VAULT_TOKEN) — handy for a person, but a root token in a script is itself a
dangerous secret. In production a *process* identifies with an **AppRole**: a role_id +
secret_id pair that is a **machine identity**, bound to a **policy** granting only the minimum
(here: read *that* secret, nothing else). The script already created it; try it:

    ansible-playbook -i inventory.ini approle.yml \
        -e role_id="$(cat /tmp/cap19-lab/role_id)" \
        -e secret_id="$(cat /tmp/cap19-lab/secret_id)"

Same secret, but the identity is no longer "the king with all the keys": it is a clerk with a
badge that opens one door — and revocable. Tokens for people, machine identities for processes
(19.4) — Question c.

### Phase 5 — no_log: the secret out of the logs (19.7 — TODO 3)

A secret fetched from the strongroom can still betray you *afterwards*: if a task prints it,
passes it to a command, or fails showing its arguments, it ends up in the logs — and logs are
kept, shipped, indexed. The safety net is **no_log: true**. Complete **TODO 3** on the task
that writes the app credential.

Running at -vvv, the protected task shows only:

    the output has been hidden due to the fact that 'no_log: true' was specified

Without no_log, the same task would print the secret in clear in the output. (The become
password is already protected by Ansible; but any *other* secret you handle yourself must be
marked no_log.)

### Phase 6 — The cloud and SSH keys (19.5, 19.6)

- **The cloud secret managers** (19.5): the same paradigm, another door. AWS Secrets Manager,
  Azure Key Vault, GCP Secret Manager are queried with their respective lookups — the plugin
  changes, not the idea. You find examples to read in start/gallery/ (amazon.aws, azure,
  google.cloud): we do not run them (they need cloud accounts), but the shape is identical to
  hashi_vault.
- **SSH keys in production** (19.6): the private key Ansible connects with is a secret too. In
  production it is not copied around by hand: it is **distributed** with the authorized_key
  module, **rotated** periodically (new pair, updated, old one revoked), and often goes through
  a single, watched **bastion** (ch. 3). The live key can itself come from a strongroom or an
  SSH CA that signs short-lived certificates.

### Phase 7 — When Vault is enough, when you need a manager (19.8)

You do not always need the strongroom. The honest rule:

- **Ansible Vault (ch. 18) is enough** when: you are alone or in a small, trusted team, secrets
  change rarely, you have no secret manager already. The encrypted strongbox in the repo is
  simple and sufficient.
- **You need a manager (ch. 19)** when: several people/teams with different access, you need
  revocation and audit, frequent rotation, dynamic secrets (expiring credentials), or a
  company Vault/cloud manager already exists to plug into.

The strongroom costs complexity (one more service to run): you pay it when the three limits of
19.1 actually hurt — Question a.

## Done when

- requirements.yml installs community.hashi_vault; hvac is in the venv.
- In group_vars/web/vars.yml the become password is a community.hashi_vault **lookup**, not a
  value.
- The playbook becomes root with the password **fetched from the strongroom**; the marker is
  root:root; on a rerun → changed=0.
- The secret secops-pw **does not appear** in the configuration (group_vars, site.yml) nor in
  the -vvv output.
- The AppRole (machine identity) reads the same secret with a read-only policy.
- The no_log-marked task shows "the output has been hidden" at -vvv.

## Questions to reflect on

**a.** Chapter 18's Vault encrypted beautifully. Which three things does it *not* solve — the
key that stays on disk, the absence of access control/revocation, the lack of audit/rotation —
and how does a secret manager fill them? When do those three limits justify the extra
complexity of a strongroom, and when is Ansible Vault enough?

**b.** Line up the three ways of giving the become password: in clear (ch. 11), encrypted in a
file (ch. 18), fetched at runtime from the strongroom (ch. 19). Where does the secret *live*
in each, and why does only the last one mean the secret never rests on disk nor travels with
the code? What changes for whoever clones the repository?

**c.** In TODO 2 you identified to the strongroom with a token; the AppRole uses role_id +
secret_id instead. Why is slipping a root token into a script as dangerous as the secret it
protects, and what does a machine identity bound to a minimal policy (read *that* secret only)
and revocable give you extra?

## Cleanup

    ./nodes.sh down        # removes cap19-web1 and cap19-vault, deletes /tmp/cap19-lab

The dev strongroom is all in memory: switch the container off and the secrets go with it.

## Where it leads

You close the theme of secrets: you can encrypt them (ch. 18) and, better, not keep them at all
but fetch them at runtime from a strongroom with identity and policy (ch. 19). From here the
manual changes register: **chapter 20** returns to the *content* of playbooks and opens
advanced Jinja2 — the filters, the transformations, the templates that give shape to the data
you have so far only passed around.
