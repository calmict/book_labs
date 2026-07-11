# Chapter 19 - Answers (model solution)

## The completed TODOs

    # TODO 1 - requirements.yml: declare the collection that talks to the vault
    collections:
      - name: community.hashi_vault
        version: "7.1.0"

    # TODO 2 - group_vars/web/vars.yml: the become password fetched at runtime
    ansible_become_password: "{{ lookup('community.hashi_vault.hashi_vault',
        'secret/data/myapp:become_password',
        url=vault_url, token=vault_token) }}"

    # TODO 3 - site.yml: no_log on the task that writes the app credential
    - name: Configure the app with its DB credential
      ansible.builtin.copy:
        content: "db_password={{ app_db_password }}\n"
        dest: /etc/myapp/db.conf
        owner: root
        group: root
        mode: "0600"
      no_log: true

solution/run.sh proves the whole arc against a real node and a real HashiCorp Vault:
the collection is declared and installed; the become password in the config is a
lookup, not a value; the play becomes root with a secret fetched from the vault at
runtime; that secret appears in no config file and in no -vvv output; the app
credential is written yet no_log keeps it out of the logs; the rerun is idempotent;
and an AppRole machine identity reads the secret under a read-only policy. nodes.sh
deposits the secret to stand in for out-of-band population, and approle.yml compares
the fetched value to the known lab value to prove correctness - both are lab
scaffolding, not the production-path config.

## The three questions

**a. The three limits Vault does not solve, and when a manager is worth it.**

Ansible Vault (ch. 18) is a strong lock on file contents, but it leaves three things
open. First, the key itself: to decrypt, the vault passphrase has to be somewhere,
and "somewhere" is either a file on disk (a secret in clear again, the chapter 11 sin
one level up) or a human typing it (which kills automation) - so the secret that
opens all the others still rests on disk. Second, access and revocation: the
passphrase is all-or-nothing and permanent; anyone who holds it reads everything it
protects, you cannot grant dev-but-not-prod, and you cannot revoke one person without
re-encrypting and redistributing to everyone else. Third, audit and rotation: an
encrypted file does not record who opened it or when, and rotating a value means
editing files and committing again, by hand, everywhere. A secret manager is built
for exactly these gaps: it stores the value centrally and hands it out over an API at
runtime (the key never rests with you), authenticates and authorises each caller so
access is per-identity and revocable, logs every read, and can rotate or even mint
short-lived dynamic secrets centrally. That power costs a service to run and operate,
so the honest call is: when you are alone or in a small trusted team, secrets change
rarely, and you have no manager already, Ansible Vault is enough; when several
people/teams need different access, you need revocation, audit, frequent rotation, or
dynamic credentials - or a company Vault already exists - the manager earns its
complexity.

**b. Where the become password lives in each of the three approaches.**

Chapter 11: the value sits in clear in the inventory - on disk, in the repository, in
Git history forever; anyone who clones reads the password. Chapter 18: the value is
encrypted in a vault file - still on disk and still in the repo and its history, but
now as ciphertext, so a clone reveals only that a secret exists and its shape, not the
value - provided the passphrase stays out of the repo (and that passphrase is now the
weak point). Chapter 19: the value is not in the repo at all - it lives in the
external vault, and group_vars holds only a lookup, a set of instructions to go and
fetch it at runtime. Only the last one means the secret neither rests on disk nor
travels with the code: it exists in memory for the length of the play and then it is
gone, and a clone of the repository contains no secret and no ciphertext of one -
just the address of the vault and the instructions to ask it, which are useless
without an identity the vault accepts. The first ships the secret to everyone with the
code, the second ships an encrypted copy plus the problem of its key, the third ships
nothing but a request.

**c. Why a root token in a script is as dangerous as the secret, and what AppRole adds.**

Because a token that can read the secret is functionally the secret: whoever gets the
token gets the value, so putting a root token in a script or an env file just recreates
the original problem one hop away - now the dangerous secret is the token, and a root
token is the worst kind because it opens not one secret but the whole vault, with no
limit and no expiry. An AppRole replaces that with a machine identity built for a
process: a role_id (which identifies the role) plus a secret_id (a credential that can
be short-lived and issued per run), bound to a least-privilege policy that in this lab
grants read on exactly one path and nothing else. The gains are real: the identity is
scoped, so even if it leaks it opens one door, not the building; it is revocable, so
you can kill that role without touching anyone else; it can be rotated and time-boxed,
so a stolen secret_id expires; and it is auditable, so the vault records that *this*
role read *that* secret. It is the difference between handing a process the king's
master key and giving it a clerk's badge that opens one drawer and can be cancelled at
the door - the badge is what you want a machine to carry.
