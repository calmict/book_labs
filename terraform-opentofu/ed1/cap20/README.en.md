# Chapter 20 — The twins and the lock

**Level:** Cloud Architect
**Estimated time:** 45–55 minutes
**Manual topics:** the history: why a fork exists (20.1), the 95% identical: compatibility (20.2), the 5% that counts: the own features — native state encryption (20.3), how to choose, with your head (20.4)

## The idea

For nineteen chapters we have said "one language, two binaries": every tofu
command has its terraform twin. This chapter keeps the promise and draws the
boundary. Because the two binaries *are* twins — born from the same code — but
from a certain point on they took different roads.

The history in brief (20.1): in 2023 HashiCorp changed Terraform's licence, from
open source to a restrictive one (the BSL). The community reacted with a *fork* —
a copy of the code that sets off on its own — placed under the Linux Foundation
and renamed **OpenTofu**, with an open licence (MPL). From there, two twin
binaries that share almost everything and diverge on a little.

The "almost everything" is the **95%** (20.2): same HCL, same providers, same
commands, the same concepts of this whole manual. You will verify it by running
the *same* configuration with both binaries and getting the same result — the
concrete proof of what we have said since chapter 6.

The "little" is the **5% that counts** (20.3), and its big piece is an old
unsettled account. Chapter 11 left us an open problem: the state keeps secrets
*in plain text*. OpenTofu solves it with a feature Terraform does not have:
**native state encryption**. You will encrypt the notebook with a passphrase,
watch the secret vanish from the file, and — the proof of the boundary — see that
terraform can no longer even read that notebook. The lock only one of the twins
has.

## Goals

By the end you will be able to:

- tell why OpenTofu exists (the 2023 licence change and the fork);
- verify the 95%: the same configuration runs identically on tofu and terraform;
- encrypt the state with OpenTofu's native encryption, keeping the passphrase
  *out* of the code (an environment variable);
- prove the 5%: an encrypted state is unreadable without the passphrase, and
  unreadable at all for terraform;
- choose between the two binaries with judgement.

## Prerequisites

- OpenTofu installed — see SETUP.md. For the boundary part you *also* need
  terraform installed (optional: if you do not have it, you read those proofs).
- No Docker, no ports: this chapter works only on state and binaries.
- Chapter 11 (the state keeps secrets in plain text): that account closes here.

## Your task

### Phase 0 — The secret in plain text (chapter 11's echo)

In start/ there is a minimal configuration: a random_password — a secret that,
once generated, lands in the state. Apply it and look at the notebook:

    cd start
    tofu init
    tofu apply
    grep -o '"bcrypt_hash"' terraform.tfstate

The secret is there, in the file, in plain text: exactly the problem chapter 11
left open. Anyone who reads terraform.tfstate reads it. Destroy and clean up
before proceeding:

    tofu destroy
    rm -f terraform.tfstate*

### Phase 1 — The 95%: the same gestures, two binaries (20.2)

If you have both binaries, try the manual's promise. With OpenTofu:

    tofu init && tofu apply

then clean the state and repeat the *same exact commands* with Terraform:

    rm -rf .terraform* terraform.tfstate*
    terraform init && terraform apply

Same HCL, same provider, same behaviour: not a line to change. This is the 95% —
the reason we wrote "tofu" throughout the manual knowing "terraform" would do the
same.

### Phase 2 — The 5%: encrypting the notebook (20.3, TODO)

Now the piece *only* OpenTofu has. Native state encryption is configured with an
encryption block — but its secret part, the passphrase, must never end up in the
code. The clean way is to pass the whole encryption configuration through the
TF_ENCRYPTION environment variable. In start/encryption.hcl.example you find the
template: key_provider (derives a key from the passphrase), method (the AES-GCM
algorithm), and state (applies the method to the state). The TODO: choose your
own passphrase (at least 16 characters) and export it — *without writing it into
any versioned file*:

    export TF_ENCRYPTION='key_provider "pbkdf2" "k" { passphrase = "choose-a-long-phrase-of-your-own" }
    method "aes_gcm" "m" { keys = key_provider.pbkdf2.k }
    state { method = method.aes_gcm.m }'

Now apply again, and look at the notebook once more:

    tofu apply
    head -c 80 terraform.tfstate
    grep -o '"bcrypt_hash"' terraform.tfstate || echo "no secret in plain text"

The file is an encrypted *envelope*: no version, no resources, no bcrypt_hash in
plain text. Chapter 11's secret is safe at rest. And note the key point: the
passphrase is in the environment, not in the repository — like chapter 14's
tfvars, the secret never travels with the code.

### Phase 3 — The two proofs of the boundary

Proof one: without the passphrase, not even you can read the notebook.

    unset TF_ENCRYPTION
    tofu state list

Error: This state file is encrypted and can not be read without an encryption
configuration. Encryption is not cosmetic: without the key, the state is opaque
to you too. (Re-export TF_ENCRYPTION to keep working.)

Proof two: the twin stays out. With the encrypted state on disk, ask terraform to
read it:

    terraform init
    terraform show

Error: Unsupported state file format. Terraform does not have native encryption:
that notebook, to it, is unreadable. It is the 5% made concrete — encrypting the
state is a door that opens in one direction only: once inside OpenTofu, going back
to Terraform is no longer free.

### Phase 4 — Choosing with your head (20.4, reflect)

The 95% says that, for most projects, the choice is reversible and low-risk: take
the binary you prefer. The 5% says *when* the choice weighs: if you need
OpenTofu's own features — native state encryption first of all — you are really
choosing OpenTofu, and going back costs. The manual's rule: choose on the 5%, not
on the 95%. Look at what you need *differently*, because that is where the twins
stop being twins.

### Cleanup

    export TF_ENCRYPTION='...your own...'   # needed to destroy the encrypted state
    tofu destroy
    rm -f terraform.tfstate* && rm -rf .terraform*
    unset TF_ENCRYPTION

## Definition of done

- In Phase 0, bcrypt_hash appeared in plain text in the unencrypted state.
- The same configuration ran identically with tofu and with terraform (Phase 1).
- With TF_ENCRYPTION set, the state became an encrypted envelope: no secret in
  plain text.
- Without the passphrase, tofu refused to read the state; terraform refused it
  entirely (Unsupported state file format).
- You answered the three questions in answers.md.

## The three questions

**a.** The fork and the two binaries: tell in three lines why OpenTofu exists
(what happened in 2023) and what, in practice, the 95% and the 5% mean. In Phase
1, what did you have to change in the code to go from tofu to terraform — and why
is the answer the thesis of the whole manual?

**b.** The lock and chapter 11: what problem, left open in chapter 11, does native
state encryption solve? Why is the passphrase passed via TF_ENCRYPTION and not
written into an encryption block inside a file — which principle (already seen
with chapter 14's tfvars) are you honouring?

**c.** The one-way door: you saw terraform fail on an encrypted state with
Unsupported state file format. Why does this make encryption a choice that *ties*
you to OpenTofu, while the rest of the 95% does not? How does this change the rule
"choose on the 5%, not on the 95%"?
