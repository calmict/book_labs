# Chapter 20 — Answers

## The secret in plain text (Phase 0)

    # grep '"bcrypt_hash"' on the UNencrypted state -> paste the result:

## The 95% (Phase 1)

    # what did you change in the code to switch tofu -> terraform?

## Encryption (Phases 2-3)

    # head of the ENCRYPTED state (envelope?):
    # tofu state list without TF_ENCRYPTION -> paste the error:
    # terraform show on the encrypted state -> paste the error:

## The three questions

**a. The fork and the two binaries.**

_(3-5 lines: why OpenTofu exists (2023); what the 95% and 5% mean; what you
changed to go tofu -> terraform, and why the answer is the manual's thesis)_

**b. The lock and chapter 11.**

_(3-5 lines: which chapter-11 problem encryption solves; why the passphrase goes
via TF_ENCRYPTION, and which principle from chapter 14's tfvars that honours)_

**c. The one-way door.**

_(3-5 lines: why terraform's "Unsupported state file format" makes encryption a
tying choice; how that changes "choose on the 5%, not the 95%")_
