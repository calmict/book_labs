# Chapter 20 — Answers (model solution)

## The secret in plain text (Phase 0)

    "bcrypt_hash"
    # (and "random_password", "result" — all in the clear in the unencrypted state)

## The 95% (Phase 1)

    # nothing: the same main.tf, the same init/apply, on both binaries

## Encryption (Phases 2-3)

    # encrypted state head: {"serial":1,"lineage":"...","meta":{"key_provider.pbkdf2.k":"eyJ...
    # tofu state list without TF_ENCRYPTION:
    #   Failed to load state: Unsupported state file format: This state file is
    #   encrypted and can not be read without an encryption configuration
    # terraform show on the encrypted state:
    #   Error: Unsupported state file format

## The three questions

**a. The fork and the two binaries.**

OpenTofu exists because in 2023 HashiCorp relicensed Terraform from an open
source licence to the Business Source Licence (BSL), a source-available but
restrictive licence. The community forked the last open version, put it under the
Linux Foundation, and named it OpenTofu (licensed MPL, genuinely open). The 95%
means the two binaries share almost everything: the same HCL, the same providers,
the same commands, the same concepts — for most work they are interchangeable.
The 5% means a small set of features diverges, and there native state encryption
is the headline. In Phase 1 I changed NOTHING in the code to go from tofu to
terraform — same main.tf, same init/apply, same result — and that is precisely
the manual's thesis: "one language, two binaries", true in the large.

**b. The lock and chapter 11.**

Native state encryption solves the problem chapter 11 left open: the state stores
every value, including the ones marked sensitive, in plain text. Anyone who can
read terraform.tfstate reads the secrets. Encryption turns the state file into an
authenticated ciphertext envelope, so at rest the secrets are unreadable without
the key. The passphrase is passed via TF_ENCRYPTION, not written into an
encryption block in a committed file, for exactly the reason chapter 14 gitignored
the tfvars: the secret must never travel with the code. The configuration (which
key provider, which cipher) can live in the repo, but the passphrase itself lives
only in the operator's environment (or a KMS) — the same separation of "the shape
is public, the secret is not".

**c. The one-way door.**

terraform failing with "Unsupported state file format" shows that an encrypted
state is not portable back to Terraform: Terraform has no native encryption, so it
cannot decrypt or even parse the envelope. Every other part of the 95% is
symmetric — a plain config and a plain state work on both binaries, so switching
back is free — but the moment you encrypt the state you depend on a feature only
OpenTofu has, and the state on disk is now OpenTofu-only. That is what makes
encryption a *tying* choice rather than a reversible one. It sharpens the rule
"choose on the 5%, not the 95%": the 95% is where the binaries are
interchangeable and the decision barely matters; the 5% is where a feature both
gives you real value (secrets safe at rest) and commits you (no free path back).
You weigh the binaries on what only one of them can do, because that is the part
you cannot walk away from later.
