# Chapter 18 — The strongbox

**Level:** Advanced

In chapter 11 you asked the caretaker for the keys: become, and for the node whose
sudo needs a password you made it work — but you wrote that password *in clear text* in
the inventory, with the promise "one day we will encrypt it". Today is that day. A
playbook ends up in a Git repository, and Git *does not forget*: a password committed in
clear stays in the history forever, even if you delete it tomorrow. This chapter — the
first of the Advanced tier — opens Ansible's strongbox: **Ansible Vault**, which
encrypts secrets *inside* your files, so the repository stays shareable and the secret
stays secret.

## Objectives

- The **original sin**: the plaintext secret, and why Git makes it eternal (18.1).
- **Encryption with a passphrase** (18.2) and the **ansible-vault commands** (18.3).
- **What an encrypted file looks like** (18.4).
- Encrypting a **single secret** with encrypt_string (18.5).
- **Running** a playbook with encrypted data: interactive, file, config (18.6).
- More secrets, more passwords: **vault-ids** (18.7).
- Vault's **limits** and what comes next (18.8); the **good habits** (18.9).

## Prerequisites

- The chapter 6 venv (or start/requirements.txt).
- The password-sudo node of chapter 11: secops returns here (sudo with a password),
  and it is his password we finally put in the strongbox.
- Docker for the ephemeral node; ansible-vault ships inside ansible-core.

## The scenario

A single node, cap18-web1, reached as **secops**: to become root you need the sudo
password (secops-pw) — exactly as in chapter 11. There it sat *in clear* in
group_vars. Here you shut it in an encrypted file (vault.yml), have a plaintext file
(vars.yml) refer to it, and the playbook becomes root *without the secret ever appearing
in clear* — not in the repository, not in the output.

This lab's **vault passphrase** is lab-vault-pass (in reality you never write it in an
exercise sheet: you keep it apart). It is the key that opens the strongbox; the sudo
password secops-pw is what sits safe *inside* it.

## Step by step

Prepare the environment:

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    cd start
    ./nodes.sh up

### Phase 1 — The original sin (18.1)

Open start/group_vars/web/vars.yml: chapter 11's shame is still there —

    ansible_become_password: secops-pw

In clear. Anyone who reads the repository reads the password; and if you commit it, it
stays in Git's history *forever*. This is the snapshot we start from — Question a.

### Phase 2 — The strongbox and the indirection key (18.2, 18.3 — TODO 1)

The cure has two moves. First: **separate** the secret from the rest. In group_vars/web/
the plaintext vars.yml will hold only a *reference*, and an encrypted vault.yml will hold
the real value. Complete **TODO 1**.

In vars.yml drop the password and put the indirection (convention: the secret variable's
name begins with vault_):

    ansible_become_password: "{{ vault_become_password }}"

Then create the encrypted file with the real value:

    ansible-vault create group_vars/web/vault.yml

(it asks for the passphrase — use lab-vault-pass — and opens the editor; write inside:)

    vault_become_password: secops-pw

If you prefer to start from a plaintext file and encrypt it *in place*:

    ansible-vault encrypt group_vars/web/vault.yml

The strongbox commands (18.3): **create** (new, encrypted), **encrypt** (encrypt an
existing file), **view** (read without changing), **edit** (edit while encrypted),
**decrypt** (back to clear), **rekey** (change the passphrase). Why two files and not one
encrypted file? Because this way git diff lets you *see the structure* (which variables
exist) without seeing the values, and you know at a glance which ones are secret —
Question b.

### Phase 3 — What the strongbox is made of (18.4)

Look at it from outside and inside:

    ansible-vault view group_vars/web/vault.yml     # inside: the value in clear
    head -1 group_vars/web/vault.yml                 # outside: ciphertext only

The first line is the signature:

    $ANSIBLE_VAULT;1.1;AES256

A header (format 1.1, cipher AES256) followed by the hex blob. Nothing readable: what
Git records is *this*, not secops-pw.

### Phase 4 — Encrypting a single secret: encrypt_string (18.5 — TODO 2)

Sometimes you do not want a whole encrypted file, but *one value* set among plaintext
variables. That is the job of **encrypt_string**: it produces a !vault block you paste
into a normal vars file. Complete **TODO 2**.

Generate the encrypted secret (an app token) with its variable name:

    ansible-vault encrypt_string --name app_api_token 'tkn-9f3a-SECRET'

Paste the output into group_vars/web/vars.yml, in place of the plaintext token: it looks
like this —

    app_api_token: !vault |
              $ANSIBLE_VAULT;1.1;AES256
              66353933... (hex lines)

The task already in the playbook writes it to /etc/myapp/token (root-owned, via become):
at runtime Ansible decrypts it, but in the file it stays encrypted. A whole encrypted
file *or* a single inline string: two tools, one strongbox.

### Phase 5 — Running with encrypted data (18.6)

The playbook now *contains* encrypted secrets: Ansible must know the passphrase to
decrypt them. Three ways, from awkward to comfortable:

    # write the passphrase to a throwaway file (never committed)
    echo 'lab-vault-pass' > vpass.txt

    ansible-playbook -i inventory.ini site.yml --ask-vault-pass          # it asks you
    ansible-playbook -i inventory.ini site.yml --vault-password-file vpass.txt   # from a file
    # or in ansible.cfg:  vault_password_file = ./vpass.txt

Without the passphrase, Ansible stops at once, and honestly:

    ERROR! Attempting to decrypt but no vault secrets found

With the passphrase, the play runs: it becomes root with the password *taken from the
strongbox*, writes the marker, and the acid test — on a rerun, **changed=0**. The secret
did its job without ever showing itself.

### Phase 6 — More secrets, more passwords: vault-ids (18.7 — TODO 3)

So far one passphrase for everything. But dev and prod should not share the same key:
whoever works in development must not be able to open the production strongbox.
**Vault-ids** give each strongbox a **label** with its own key. Complete **TODO 3**:
encrypt prod_secret.yml labelled prod.

    ansible-vault encrypt --encrypt-vault-id prod --vault-id prod@prompt prod_secret.yml

The header now *carries the label*:

    $ANSIBLE_VAULT;1.2;AES256;prod

(note the **1.2** format: the version that adds the label). And run prod.yml passing
*all* the identities you hold — Ansible tries the right one for each block:

    echo 'prod-pass' > prod-pass.txt
    ansible-playbook -i inventory.ini prod.yml \
        --vault-id lab@vpass.txt --vault-id prod@prod-pass.txt

One run, two keys: lab opens the become-password vault, prod opens the production
secret. This lab's prod label passphrase is prod-pass.

### Phase 7 — The limits, and the good habits (18.8, 18.9)

- **Vault encrypts the *content*, not the *existence*.** Whoever has the repository sees
  *that* a secret exists and what the variable is called; not its value. And whoever has
  the passphrase has everything: Vault is a strongbox, not a permissions system.
- **The passphrase is the real secret now.** Never commit it (vpass.txt is not
  versioned); in production it comes from an external manager — that is chapter 19.
- **Good habits** (18.9): separate vault.yml (encrypted) from vars.yml (clear, with the
  references); prefix secret variables with vault_; encrypt *the bare minimum*, not the
  whole project; rotate keys with rekey; and a secret committed in clear *even once*
  must be treated as **compromised** and changed — Git does not forget.

## Done when

- group_vars/web/vars.yml holds **no** plaintext password: only the
  {{ vault_become_password }} indirection and the inline !vault block.
- group_vars/web/vault.yml is encrypted (first line $ANSIBLE_VAULT;1.1;AES256);
  ansible-vault view shows the value.
- The playbook becomes root with the password taken from the vault and writes the
  root:root marker; on a rerun → **changed=0**.
- Without the passphrase the playbook fails with "Attempting to decrypt but no vault
  secrets found".
- The prod-labelled secret has the header ;1.2;AES256;prod and decrypts with its
  vault-id.

## Questions to reflect on

**a.** Chapter 11's password sat in clear in the inventory and "worked". Why is
committing it even once a problem that *deleting it tomorrow* does not fix? What does Git
record, and what should you do with the secret once it has landed in the history?

**b.** You could encrypt one big file with all the variables, secret and not. Why is it
better to separate vault.yml (encrypted) from vars.yml (clear, with the {{ vault_* }}
references)? What do you gain when you git diff or reread the project six months later?

**c.** Vault encrypts the secret's *value*, but anyone with the passphrase opens it, and
anyone with the repository sees *that* the secret exists. Why is Vault not an access
control system, and which problem — that of the *passphrase itself* — stays open and
leads you straight to chapter 19?

## Cleanup

    ./nodes.sh down        # removes cap18-web1

The vpass.txt file with the passphrase is local and throwaway: it never ends up in the
repository.

## Where it leads

You have closed the account left open by chapter 11: the password is no longer in clear.
But the paradox remains: the strongbox is safe, and its **key** — the vault passphrase —
where is it? If you write it in a file next to the playbook, you have only moved the
problem. **Chapter 19** takes up exactly this: key management in production, where the
secret that opens the other secrets no longer lives on disk, but arrives at runtime from
an external manager.
