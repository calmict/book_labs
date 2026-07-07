# Chapter 21 — Answers

## The base (Phase 0)

    # tofu fmt -check output (silence = ok):
    # tofu validate output:

## The tests (Phase 2)

    # tofu test output after completing TODO 1 and 2 (paste the run lines):

## Rejecting a regression (Phase 3)

    # after breaking container_name, tofu test -> paste the failing assertion:

## The three questions

**a. The pyramid's shape.**

_(3-5 lines: why fmt/validate at the base and tofu test at the top; what each
floor catches; an error only a behaviour test catches)_

**b. expect_failures.**

_(3-5 lines: why testing a rejection matters as much as testing success; what the
run proves about chapter 14's validation)_

**c. Policy as code and the bridge.**

_(3-5 lines: convention vs policy as code; why the pyramid is best when automatic
on every commit)_
