# Chapter 5 — Answers (model solution)

## The engine, at a glance

    bash solution/ensure.sh /tmp/cap05-state     # first run:  all [changed]
    bash solution/ensure.sh /tmp/cap05-state     # second run: switch/render [ok], doorbell [changed]
    CHECK=1 bash solution/ensure.sh /tmp/fresh    # says WOULD, writes nothing

solution/run.sh drives the whole arc with assertions; pure files, guaranteed cleanup.

## The three completed pieces

The switch (idempotent, check-aware):

    if [ -f "$file" ] && grep -qxF "$line" "$file"; then report ok ...; return; fi
    if [ "$CHECK" = 1 ]; then report changed "WOULD add ..."; return; fi
    echo "$line" >> "$file"; report changed "added ..."

changed_when for the black swan (judge by comparing, not by exit code):

    printf '%s\n' "$desired" > "$file"     # always runs
    if [ "$before" = "$desired" ]; then report ok; else report changed; fi

## The three questions

**a. Idempotence, and why it makes re-running safe.**

An operation is idempotent when applying it any number of times leaves the system in
the same state as applying it once: the result depends on the *desired end state*,
not on how many times you ran it. That is exactly what makes an automation safe to
re-run, and it is the missing half of chapter 1. There, a guarded script was
*re-runnable* (it did not crash on the second run) but not *convergent* (drift
survived). Idempotence is the stronger property: not only does re-running not break,
it actively brings reality to the declared state and reports "ok" when there was
nothing to do. Once every operation is idempotent, running the whole automation
becomes consequence-free when nothing has drifted, and self-correcting when something
has — so you can run it on a schedule, after every commit, or in a panic at 3am, and
trust that it converges rather than piling up side effects like a doorbell.

**b. Why a shell command is a black swan, and what changed_when gives it.**

A well-written module is a switch: it inspects the current state, acts only if
needed, and therefore *knows* whether it changed anything. A raw shell (or command)
task cannot: it just runs a command and gets back an exit code. Exit 0 means "the
command succeeded", which says nothing about whether the system changed — running
"systemctl restart" or "echo ... > file" or a REST call succeeds every time, so a
naive engine would paint it yellow ([changed]) on every run, forever. That permanent
false "changed" is the black swan: it breaks the whole value of the colours (you can
no longer tell a real change from noise, and handlers that fire on change fire every
time). changed_when gives you back the judgement the command threw away: you tell the
engine how to decide "changed" from evidence you trust — compare a file's content
before and after, inspect the command's stdout, check a marker — instead of assuming
the mere fact that it ran means something changed. It is you supplying the "did it
actually change?" logic that a switch has built in and a bare command does not.

**c. The limit of check mode.**

Check mode predicts each task in isolation against the *current* reality, because it
deliberately does not perform the changes. So when task B depends on the *effect* of
task A, the dry run cannot predict B honestly: A did not really run, so the thing A
would have created does not exist, and B is evaluated against a world where A's effect
is missing. B may report "would change" based on stale reality, or error because a
file/package/service A was supposed to create is not there, or be skipped because a
fact A would have set was never gathered. In other words, --check is a faithful
rehearsal only for tasks that are independent of earlier changes in the same run;
for a chain of dependent tasks it shows you the first domino, not the ones that would
fall after it. That is why check mode is a smoke test and a diff preview, not a proof
that a multi-step play will succeed end to end.
