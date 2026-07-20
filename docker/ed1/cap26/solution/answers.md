# Chapter 26 — Answers

## The completed TODOs

**TODO 1 (26.1) — the container's logs:**

    logs=$(docker logs "$C" 2>&1)

**TODO 2 (26.2) — the exit code:**

    exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$C")

**TODO 3 (26.3) — the restart counter and final status:**

    restart_count=$(docker inspect -f '{{.RestartCount}}' "$C")
    status=$(docker inspect -f '{{.State.Status}}' "$C")

## Reflection questions

**a. How do you diagnose when the logs do not help?**

Empty logs are not a dead end, they are a clue: the container produced no output before
dying. It may have crashed before reaching any print statement, written to a file inside
its filesystem instead of stdout/stderr, run its real process as a child of a shell that
swallowed the output (chapter 10, the exec vs shell form), or buffered output that was
never flushed. When the logs are silent, docker inspect is the first foothold: it holds the
exit code, the state, the error message the runtime recorded, the OOMKilled flag, the start
and finish times. You read those before anything else, because they tell you how the
container died even when it never said a word.

**b. Restart policies and the crash loop.**

A restart policy tells Docker what to do when a container exits: no (never), on-failure
(only on a non-zero exit, up to a limit), always, unless-stopped. always on a container
that crashes immediately is a loop with no end condition — it dies, restarts, dies again —
so Docker inserts a growing backoff (each restart waits longer) to keep it from hammering
the machine. RestartCount and the state make it visible: a count climbing while the status
flips between restarting and exited is the signature of a crash loop. Kubernetes shows the
exact same thing under a name you will meet often — CrashLoopBackOff — for the exact same
reason, with the exact same backoff.

**c. Why read the exit code first?**

Because it is the fastest, most reliable classification of the failure. 137 is SIGKILL,
and with the OOMKilled flag it means the kernel's OOM killer stopped the container for
using too much memory (chapter 3); 143 is a clean SIGTERM (chapter 7); 42 or any other
application code means the program decided to exit that way, so the bug is in the app, not
the platform; 127 is "command not found" (a bad ENTRYPOINT/CMD or a missing binary); 126 is
"not executable" (a permission or format problem). Each number points you at a different
part of the stack before you have read a single log line, which is why it is the first
question of every container postmortem.
