# Chapter 8 — Answers

## The two worlds (Phase 0)

    # paste the two ServerVersion answers (local and tcp 23750):

## Who sees what (Phase 3)

    # paste: tofu state list (4 resources)

    # paste: docker ps names (Milan side) and docker -H tcp://... ps names

## The asymmetric demolition (Phase 5)

    # after tofu destroy: what does docker -H tcp://127.0.0.1:23750 ps -a
    # show, and is cap08-frankfurt-dc still alive?

## The three questions

**a. Translator and telephones.**

_(4-6 lines: one binary vs two configured lines; why the image needed the
placement too; the default-line fate of an unmarked resource)_

**b. The ladder of trust.**

_(4-6 lines: where the AWS credentials come from, what assume_role adds —
duration, perimeter, revocation — and why the committed password is
permanent damage)_

**c. The asymmetric demolition, and the lab shortcut.**

_(4-6 lines: what destroy removed through which lines, what it left and
why that boundary is right, what plaintext 23750 would require in
production)_
