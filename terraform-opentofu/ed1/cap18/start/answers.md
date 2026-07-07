# Chapter 18 — Answers

## The naive rename (Phase 0)

    # rename app -> frontend WITHOUT a moved block, tofu plan -> paste the
    # two lines (one destroyed, one created):

## moved (Phase 1)

    # with the moved block -> paste the "has moved to" line and the Plan: line
    # container ID before / after (same?):

## removed and import (Phases 2-3)

    # removed -> the "will be removed from ... but will not be destroyed" line
    # cache container status after apply:
    # import -> the Plan: line (how many to import, how many to destroy?)

## The three questions

**a. The address is the identity.**

_(3-5 lines: why the naive rename destroys+creates though the real container is
identical; what Terraform compares; the link to chapter 11)_

**b. removed versus a destroy.**

_(3-5 lines: removing without vs with a removed block; when the container dies
vs survives; why OpenTofu and Terraform syntax differ)_

**c. import and the scalpel.**

_(3-5 lines: why the volume import had 0 to change while a hand-made container
forces a replace; the resource-vs-object relationship; why blocks beat state
commands — what a plan gives you)_
