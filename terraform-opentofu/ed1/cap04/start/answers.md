# Chapter 4 — Answers

## The stopwatch (Phases 0 and 1)

    # real time of the Phase 0 apply (no edges):
    # real time of the Phase 1 apply (chained):

## Your edges in tofu graph (Phase 3)

    # paste the three lines with your edges
    # (floor_2 -> floor_1, floor_3 -> floor_2, certificate -> floor_3)

## The demolition order (Phase 4)

    # paste the Destroying... lines in the order they appeared

## The forbidden cycle (Phase 5)

    # paste the error line printed by tofu validate

## The three questions

**a. Where did each edge come from, which way do the arrows point, and when
is depends_on the right call?**

_(4-6 lines: references as implicit edges, the arrow as "depends on", and
the case where no value flows)_

**b. Explain 5 seconds versus 15 in terms of the graph, and why a cycle
admits no execution order — caught before touching reality.**

_(4-6 lines: parallel crews on unlinked nodes, the chain forcing waits, and
what it means that validate finds the cycle)_

**c. The complete thread of Part 1, and why reverse-order demolition is a
necessity.**

_(4-6 lines: from describing the result to reality resembling it — drift,
convergence, immutability, graph — plus chapter 3's image and container)_
