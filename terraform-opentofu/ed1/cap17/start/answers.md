# Chapter 17 — Answers

## Installing the box (Phase 2)

    # paste the line tofu init printed for the module:

## The module namespace (Phase 3)

    # tofu state list -> paste the module-prefixed addresses:
    # tofu output urls:

## One box, many instances (Phase 4)

    # removing shop from the map, tofu plan -> what is destroyed, what is not:

## The three questions

**a. The box and its doors.**

_(3-5 lines: variables/resources/outputs mapped to input doors/machinery/output
doors; why outputs are the interface; what the author can change without
breaking users, and what not)_

**b. Provider inheritance.**

_(3-5 lines: why no provider block in the module; what changes for an aliased
provider and the line that does it; why it is the caller's choice)_

**c. The Registry and the bridge.**

_(3-5 lines: why pinning version matters like chapter 7's lock; why wrapping in
a module changed the address and why that is a problem; which Part 5 chapter
solves it)_
