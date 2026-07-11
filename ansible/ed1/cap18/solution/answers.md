# Chapter 18 - Answers (model solution)

## The completed TODOs

    # TODO 1 - group_vars/web/vars.yml: indirection, not the secret
    ansible_become_password: "{{ vault_become_password }}"

    # TODO 1 - group_vars/web/vault.yml (created with ansible-vault create,
    # passphrase lab-vault-pass), shown here decrypted:
    vault_become_password: secops-pw

    # TODO 2 - group_vars/web/vars.yml: a single secret encrypted inline,
    # produced by ansible-vault encrypt_string --name app_api_token 'tkn-9f3a-SECRET'
    app_api_token: !vault |
              $ANSIBLE_VAULT;1.1;AES256
              6230303439... (hex body)

    # TODO 3 - prod_secret.yml encrypted under its own vault-id:
    #   ansible-vault encrypt --encrypt-vault-id prod --vault-id prod@prompt prod_secret.yml
    # header becomes:  $ANSIBLE_VAULT;1.2;AES256;prod
    # run with both identities:
    #   ansible-playbook -i inventory.ini prod.yml \
    #       --vault-id lab@vpass.txt --vault-id prod@prod-pass.txt

solution/run.sh proves the whole arc against a real node: the plaintext password
is gone; vault.yml decrypts; a run without the passphrase refuses ("Attempting to
decrypt but no vault secrets found"); with it the play becomes root using a secret
it never prints, writes the marker and the token, and is idempotent on a second
run; the token is an inline !vault block; and the prod secret sits under its own
vault-id, with a single run supplying two identities. Node teardown is guaranteed.

## The three questions

**a. The password "worked" in clear text - why is committing it once a problem
that deleting it tomorrow does not fix?**

Because Git does not store the current state of a file, it stores its whole
history, and a secret committed once lives in that history forever - in every
clone, every fork, every backup, every CI cache that ever pulled the repo.
Deleting the line in a new commit only changes the tip: the old commit still
contains the password, and anyone with the repository can walk back to it with a
one-line git log -p or git show. Rewriting history to excise it (filter-repo,
BFG) is possible but disruptive, never reaches copies other people already have,
and is useless the moment the repo was public or shared. So the honest rule is:
a secret that has been committed in clear text even once is compromised. The fix
is not to scrub the file, it is to rotate the secret - change the password on the
node so the leaked one no longer opens anything - and only then commit the value
encrypted, so that what Git remembers forever is ciphertext, not the password.
Vault does not undo the leak; it prevents the next one.

**b. You could encrypt one big file with everything in it. Why split vault.yml
(encrypted) from vars.yml (plaintext, with the {{ vault_* }} indirections)?**

Because encryption hides values, and hiding too much costs you the things plain
text is good for. If the whole file is encrypted, then to see *which* variables a
group even has - the shape of your configuration - you must decrypt, and git
diff on a change shows one opaque blob turning into another opaque blob, so code
review of non-secret changes becomes blind. Splitting keeps the readable
structure readable: vars.yml shows every variable name and every non-secret value
in clear, so a reviewer sees what changed and a newcomer sees how the group is
wired, while vault.yml holds only the handful of actual secrets. The vault_
prefix and the {{ vault_become_password }} indirection make the seam obvious:
you can tell at a glance which values are sensitive and where they come from,
without decrypting anything. It is the same instinct as encrypting the minimum:
protect the secret, expose the structure. One giant encrypted file protects the
secret too, but it drags all the harmless, useful context into the dark with it.

**c. Vault encrypts the value, but anyone with the passphrase opens it, and
anyone with the repo sees that the secret exists. Why is Vault not access
control, and what problem does it leave open for chapter 19?**

Because Vault is a lock on the *content*, not a policy about *who*. It answers
"can this ciphertext be turned back into plain text?" - yes if you hold the
passphrase, no otherwise - and that is all it answers. It does not know who you
are, cannot grant one person read of the dev secrets but not prod (vault-ids help
organise passphrases, but whoever has a passphrase has everything it protects),
keeps no audit of who decrypted what, and cannot revoke access to a value already
decrypted on someone's laptop. It also hides only the value: the repository still
reveals that a secret exists and what its variable is called. So Vault moves the
problem rather than removing it - now the real secret is the *passphrase*, the one
key that opens all the others. Put that passphrase in a file next to the playbook
and you are back where chapter 11 started, a secret sitting in clear on disk; type
it by hand and you cannot automate. That unresolved question - where the key that
opens the vault actually lives, and how it reaches the run without being stored -
is exactly what chapter 19 takes up: production key management, where the secret
that unlocks the others comes from an external manager at runtime and never rests
on disk at all.
