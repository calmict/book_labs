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

**b. Why does exec form make your process PID 1, while shell form does not?**

In exec form (ENTRYPOINT ["/entry.sh"]) Docker execs your program directly, so it
is the container's PID 1. In shell form (ENTRYPOINT /entry.sh) Docker runs
/bin/sh -c "/entry.sh": now the shell is PID 1 and your program runs under it. This
matters because of chapter 7: docker stop sends SIGTERM to PID 1. If PID 1 is your
app (exec form), it receives the signal and can shut down cleanly; if PID 1 is a
shell that does not forward signals, your app never hears SIGTERM, the grace period
elapses, and the container is SIGKILLed after "ten seconds" (exit 137). Exec form,
plus a real init when you need one (--init, chapter 7), is how you avoid that.

**c. When CMD alone, ENTRYPOINT alone, or both?**

Use CMD alone for a generic image whose command you often replace (a base you run
different things in): docker run image <anything> just works. Use ENTRYPOINT alone,
or ENTRYPOINT + CMD, for an "executable" image — a tool that should always run the
same program, taking arguments: ENTRYPOINT fixes the program, CMD supplies a
default argument, and users pass their own arguments without repeating the program
name. When you genuinely need to run something else in an ENTRYPOINT image — a
shell to debug it, say — docker run --entrypoint sh image overrides the captain for
that one run.
