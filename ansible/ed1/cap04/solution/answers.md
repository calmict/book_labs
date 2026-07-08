# Chapter 4 — Answers (model solution)

## The reveal

    python3 solution/inspect.py start/config.yml     # the traps: NO->False, 1.20->1.2, 0644->420, 22:30->1350
    python3 solution/inspect.py solution/config.yml   # fixed: all strings; web/db share &defaults

solution/run.sh drives the whole arc (silent traps, loud traps, the quoted fix, the
anchor+merge, block scalars) with assertions; pure files, nothing to tear down.

## The fix, in two moves

Quoting the ambiguous values, and factoring the shared host settings:

    country: "NO"          # instead of NO -> False
    version: "1.20"        # instead of 1.20 -> 1.2
    file_mode: "0644"      # instead of 0644 -> 420
    window: "22:30"        # instead of 22:30 -> 1350

    defaults: &defaults
      retries: 3
      timeout: 30
      healthcheck: /healthz
    hosts:
      web: { <<: *defaults, role: frontend }
      db:  { <<: *defaults, timeout: 60, role: database }

## The three questions

**a. Silent vs loud.**

A loud trap (a colon in an unquoted value, a bad indent) is a parse error: the file
does not load at all, so you find out immediately, on your machine, before anything
runs. A silent trap loads perfectly and simply means the wrong thing — and nothing
warns you. That is worse precisely because it is invisible: the playbook runs, the
value is used, and the damage surfaces far from the cause. Concretely, a task that
receives the boolean False where you wrote the string "NO" will misbehave wherever
that value is compared or rendered: a when condition that tests the country code
never matches, a template prints False instead of NO, a country-specific branch is
silently skipped. You debug the symptom (a feature "not applying") with no hint that
the root cause was two unquoted letters the parser decided meant "false". Loud fails
fast; silent fails late and lies about where it came from.

**b. The lost trailing zero, and the rule.**

version: 1.20 parses as the float 1.2, and 1.2 == 1.20 as a number — the trailing
zero is gone, and worse, it is now a float, not a string. For a version number that
is a disaster because versions are not arithmetic: "1.20" and "1.2" are different
releases, "1.10" sorts after "1.9" as versions but the float 1.10 equals 1.1 and is
less than 1.9. Any comparison, lookup, or filename built from the version is now
wrong, and float rounding can even change the value you print. The general rule: a
value is only safe unquoted when you genuinely want YAML's guessed type and the
guess is unambiguous. Quote anything that is conceptually a string even though it
looks like a number or a keyword — version numbers, permissions/modes with a leading
zero, two-letter codes (country, language, US state), times and dates, phone numbers,
git shas, anything with a leading zero, and of course yes/no/on/off/true/false when
you meant the word, not the boolean. When in doubt, quote: quoting a real string
never changes its meaning, leaving it unquoted sometimes does.

**c. The cost of anchors, and roles.**

Anchors and merge remove duplication, but they add indirection: to understand what
web actually is, a reader must find the &defaults anchor elsewhere in the file, merge
it in their head, and then apply the local overrides — and merge semantics are subtle
(what wins on a conflict, whether nested maps deep-merge, the fact that << is a
YAML 1.1 feature some tools handle differently). In a small file it is a fair trade;
across many large files it becomes a puzzle, and a change to the anchor silently
changes every host that merges it, which is powerful and dangerous. Roles (chapter 16)
answer the same reuse need at a higher level: instead of textual merging inside one
YAML file, they package the reusable behaviour — tasks, defaults, templates, handlers —
into a named, versioned unit with a clear interface (its variables) and clear
precedence rules. Reuse becomes "apply the role with these parameters", which is
discoverable, testable and shareable, rather than "chase this anchor through the
file". Anchors dedupe text; roles dedupe behaviour.
