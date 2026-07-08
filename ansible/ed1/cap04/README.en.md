# Chapter 4 — The score that lies

**Level:** Foundational

YAML is the score you will write every playbook and every inventory on. It looks
trivial — and that is exactly the trap: a value written the way you mean it can be
**read by the parser as something else entirely**. NO becomes False, 1.20 becomes
1.2, 22:30 becomes 1350. In this lab you learn the anatomy of YAML and, above all,
how not to let the score lie to you. No containers, no Ansible yet: just YAML files
and **the very parser Ansible uses under the hood** (PyYAML).

## Objectives

- The three structures — **scalar, list, dictionary** — and nesting by indentation.
- The **silent** traps (Norway Problem, implicit typing, leading zeros, base 60)
  and the **loud** ones (colons, indentation).
- **Quoting**: when and why to add the quotes.
- **Block scalars**: the pipe | (literal) and the greater-than > (folded).
- **Anchors and merge** << for reuse (DRY).
- **yamllint** as the safety net.

## Prerequisites

- python3 with **PyYAML** (it comes with Ansible). Check with:
  python3 -c "import yaml"
- yamllint is optional (present in CI, may be missing locally).
- **No containers, no Ansible**: we are still in the "before".

## The scenario

A deploy config file that *looks* correct. You feed it to the parser and discover
that several lines do not mean what you thought. Then you fix it — quoting what is
ambiguous and removing the duplication with anchors.

## Step by step

### Phase 1 — See what the parser ACTUALLY reads

    python3 solution/inspect.py start/config.yml

The tool prints each value with the **type** the parser gave it. Look at the
surprises:

    'country':   False   (bool)     <- you wrote NO, the code for Norway
    'version':   1.2     (float)    <- you wrote 1.20
    'file_mode': 420     (int)      <- you wrote 0644
    'window':    1350    (int)      <- you wrote 22:30

The score lies: you put NO for "Norway", the parser understood "false". This is the
**Norway Problem**, and with it the whole family of **implicit typing**: YAML
*guesses* the type, and sometimes it guesses wrong.

### Phase 2 — The loud traps (which at least shout)

Not every trap is silent. Try to make the parser load an unquoted value with a
colon, and a wrong indentation:

    printf 'note: value with: a colon\n' | python3 -c 'import sys,yaml; yaml.safe_load(sys.stdin)'
    printf 'a: 1\n  b: 2\n'              | python3 -c 'import sys,yaml; yaml.safe_load(sys.stdin)'

Both fail with an error. Good: the **loud** trap you see at once and fix. The silent
one from Phase 1 — the one that loads perfectly and means the wrong thing — is the
one that bites you in production.

### Phase 3 — TODO 1: quote what is ambiguous

Open start/config.yml. Put **quotes** around the values the parser misreads, so they
stay what you meant (strings). The build field is already done as an example:

    build: "1.10"

Do the same for country, maintenance, version, file_mode, device_id, window. Then
re-run:

    python3 solution/inspect.py start/config.yml

Now country is "NO", version is "1.20", all strings. The golden rule: **when in
doubt, quote** — especially two-letter codes, version numbers, permissions with a
leading zero, times.

### Phase 4 — Block scalars: | keeps newlines, > folds them

The motd field uses the **literal** |, which preserves the lines as they are:

    motd: |
      welcome to web
      authorized use only

inspect.py shows it to you with the \n inside. If you used the **folded** >, the
lines would merge into one separated by spaces. The first is for config files and
keys; the second for long text you want to wrap comfortably.

### Phase 5 — TODO 2: remove duplication with anchors and merge

In the hosts block, web and db repeat the same settings. Give the shared block an
**anchor** and **merge** it into each host with <<, overriding only what differs (db
needs a longer timeout):

    defaults: &defaults
      retries: 3
      timeout: 30
      healthcheck: /healthz
    hosts:
      web:
        <<: *defaults
        role: frontend
      db:
        <<: *defaults
        timeout: 60
        role: database

Re-run inspect.py: web and db **inherit** the defaults, and db keeps its override at
60. (Note: << is a YAML 1.1 convenience; useful to recognize, but for serious reuse
the roles arrive, chapter 16.)

### Phase 6 — The safety net: yamllint

The human eye is not enough: NO and "NO" look identical. **yamllint** reads the
score with the parser's strictness and flags exactly these things — the truthy rule
shouts on no/NO/off/yes — *before* Ansible misreads them:

    yamllint start/config.yml

It is the chapter's last line of defense: do not trust the eye, run every YAML
through the checker.

## Done when

- inspect.py on start/config.yml shows the **mis-typed** values (country bool,
  version float, file_mode int…).
- After TODO 1, the same values are **strings**.
- After TODO 2, web and db **share** &defaults via << and db **overrides** only the
  timeout.
- You can explain the difference between a loud trap and a silent one, and why the
  second is worse.

## Questions to reflect on

**a.** Why is the **silent** trap (NO → False) more dangerous than the **loud** one
(a parse error)? What happens to a task that receives the boolean False where you
expected the string "NO"?

**b.** version: 1.20 becomes 1.2 and loses the trailing zero. For a version number
why is that a disaster, and what is the **general rule** on when to quote a value?

**c.** Anchors with merge remove the duplication, but they add a cost: which one,
for whoever reads and maintains the file months later? And how will **roles**
(chapter 16) tackle the same reuse need in a more structured way?

## Cleanup

None: this chapter is made only of files, no containers.

## Where it leads

Every playbook, inventory and variables file you will write is YAML — and now you
know the score must always be re-read with the parser's eye. In chapter 8
(inventories) and chapter 12 (variables) these traps become real bugs: quote them
before they bite.
