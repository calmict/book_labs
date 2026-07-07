# Chapter 15 — Answers

## The fragile index (Phase 1)

    # count addresses, then remove bravo -> paste the two lines
    # (one replace, one destroy):

## Counting by name (Phase 2)

    # for_each addresses, then remove bravo -> paste the plan summary
    # (0 add, 0 change, 1 destroy) and which one is touched:

## The conditional and the dynamic block (Phases 3-4)

    # canary_enabled=true plan summary:
    # docker inspect labels on cap15-alpha:

## The three questions

**a. The trap.**

_(3-5 lines: why removing bravo replaced charlie and destroyed the last while
alpha survived; what ties count to identity; why the name change forced a
replace, and which chapter)_

**b. List vs set.**

_(3-5 lines: why for_each wants a set/map not a list; what a list has that must
not matter here; what toset() does; why bravo's removal no longer touches the
others)_

**c. The two multiplications.**

_(3-5 lines: count/for_each multiply resources, dynamic multiplies blocks — an
example of each; why count = 0 is the idiomatic optional, not commenting out)_
