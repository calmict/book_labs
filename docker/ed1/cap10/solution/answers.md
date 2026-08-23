# Chapter 10 — Answers

## The completed TODOs

**TODO 1 (10.3) — load the entrypoint script:**

    COPY entry.sh /entry.sh

**TODO 2 (10.3) — the fixed executable, exec form (PID 1):**

    ENTRYPOINT ["/entry.sh"]

**TODO 3 (10.5) — default arguments for the entrypoint:**

    CMD ["default"]

## Reflection questions

**a. How do ENTRYPOINT and CMD combine, and what happens with run arguments?**

When only CMD is set, it is the whole default command, and passing a command to
docker run replaces it completely. When ENTRYPOINT is set, it is the fixed
executable and CMD becomes merely its *default argument list*: at startup Docker
runs ENTRYPOINT followed by CMD (or by whatever arguments you pass to docker run,
which replace CMD). So in the lab, "docker run image" runs /entry.sh default, while
"docker run image foo bar" runs /entry.sh foo bar — the captain (ENTRYPOINT) never
changes, only the orders (the arguments) do. This is why an "executable" image
usually pairs ENTRYPOINT (the tool) with CMD (a sensible default argument), and why
--entrypoint exists for the rare case you must replace the captain itself.

**b. What really tells the slow case apart, and why does PID 1 survive SIGTERM?**

Phase 5 measures it instead of assuming it. In exec form Docker execs your program
directly: the script is PID 1, its SIGTERM handler runs, the container is gone in
about a second with exit code 0. In shell form Docker runs /bin/sh -c "..." — but
what happens next depends on what the shell was given. With something after the
script (CMD /entry.sh serve; echo stopped) the shell must stay to run the rest, so
it keeps PID 1 and the script runs beside it as PID 7: docker stop signals PID 1,
the shell has no handler for it, nothing is forwarded, the grace period expires and
the container is killed — exit 137. With the script as the shell's only command
(CMD /entry.sh serve) busybox's shell does not wait around: it replaces itself with
the script, PID 1 is the script again, and the shutdown is prompt once more. So the
form of the CMD is not the cause; a shell left in the middle is. Exec form is worth
preferring because it removes the question altogether, not because shell form is
slow by nature.

The second half of the question is the reason the slow case is so slow. The kernel
gives PID 1 no default action for signals: a normal process with no handler for
SIGTERM is terminated by the kernel, but PID 1 with no handler simply ignores it.
That is why the wrapping shell neither dies nor forwards, and why the only way out
is SIGKILL when the grace period ends (chapter 7). Exec form, plus a real init when
you need one (--init, chapter 7), is how you avoid that.

**c. When CMD alone, ENTRYPOINT alone, or both?**

Use CMD alone for a generic image whose command you often replace (a base you run
different things in): docker run image <anything> just works. Use ENTRYPOINT alone,
or ENTRYPOINT + CMD, for an "executable" image — a tool that should always run the
same program, taking arguments: ENTRYPOINT fixes the program, CMD supplies a
default argument, and users pass their own arguments without repeating the program
name. When you genuinely need to run something else in an ENTRYPOINT image — a
shell to debug it, say — docker run --entrypoint sh image overrides the captain for
that one run.
