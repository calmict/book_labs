# Chapter 2 — Answers (model solution)

## The naive recipe, second run (Phase 0)

    mkdir: cannot create directory 'fleet': File exists

## The blind guard (Phase 2)

    step 2.2: server-2 already exists, skipping
    debug_mode = on

## The four starting points (Phase 4)

    # empty yard:        Plan: 4 to add, 0 to change, 0 to destroy.
    # vandalised:        Plan: 1 to add, 0 to change, 0 to destroy.
    # half-built:        Plan: 2 to add, 0 to change, 0 to destroy.
    # already complete:  No changes. Your infrastructure matches the configuration.

## The three questions

**a. Why did the naive recipe blow up on the second run, and what exactly did
the guards add — and not add?**

The naive recipe encodes the HOW from one assumed starting point: an empty
yard. On the second run reality no longer matches that assumption, so the
very first step (mkdir) is nonsense and the script dies. The guards added
one thing only: a check on EXISTENCE before each action, which buys
re-runnability — the script no longer crashes, whatever has already been
done gets skipped. What they did not add is a check on CONTENT: the
vandalised server-2 exists, so the guard skips it, and debug stays on.
Re-runnable means "safe to launch again"; convergent means "reality ends up
matching the model". To get the second by hand you would have to diff every
file against its desired content — rewriting, in bash, the core business of
a declarative tool. (And the naive alternative — always overwrite — fails
the other way: it would fix the config but append the inventory forever.)

**b. Who computes the steps now, and from which two ingredients? What did
you stop having to know?**

The tool computes them, at every apply, from exactly two ingredients: the
desired model (main.tf) and the current reality (what is actually on disk,
tracked through its state). That is why one identical command produced four
different plans: 4 to add from the empty yard, 1 from the vandalised start,
2 from the half-built one, none from the complete one — the model never
changed, reality did, and the plan is the computed difference between the
two. What I stopped having to know is the starting point: with a recipe I
must know where I stand to pick the right steps (or write guards for every
possibility); with a photograph the starting point is the tool's problem,
not mine. I state the destination, it derives the route.

**c. When does the recipe remain the right choice, and why does this split
prepare immutability?**

The recipe remains right for actions that are events, not states: a
timestamped backup ("dump the database NOW, into a file named with this
instant") describes an occurrence, not a desired permanent condition — a
photograph of it would try to make that moment permanent, which is
meaningless. Same for a one-shot data migration or a reboot: "restart the
server" is a step by nature; there is no end-state called "having been
restarted" worth converging to. The rule of thumb: states are photographed,
events are scripted. And the split prepares immutability because once you
think in desired states, repairing a drifted object by hand stops making
sense: the natural gesture is the one chapter 1 showed — throw the mutant
away and re-cast it from the model. In the imperative world repair feels
normal (another step!); in the declarative world replacement is cheaper,
safer and already automated. Chapter 3 builds exactly on this.
