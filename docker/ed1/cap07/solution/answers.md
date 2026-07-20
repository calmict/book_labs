# Chapter 7 - Dying gracefully - answers

## The completed TODOs

TODO 1 (7.3) - stop the container with the grace period and time it. docker stop
sends SIGTERM, waits GRACE seconds, then SIGKILLs:

    local t0 t1
    t0=$(date +%s%N)
    docker stop -t "$GRACE" "$n" >/dev/null
    t1=$(date +%s%N)

TODO 3 (7.3) - print the elapsed milliseconds and the exit code. The exit code
tells the whole story: 137 (SIGKILL) if PID 1 ignored SIGTERM, 143 (SIGTERM) if
it stopped cleanly:

    echo "$(( (t1 - t0) / 1000000 )) $(docker inspect -f '{{.State.ExitCode}}' "$n")"

TODO 2 (7.5) - container B must run with --init, so tini becomes PID 1 and
forwards SIGTERM to sleep, which then terminates at once:

    read -r b_ms b_code < <(measure b --init)

## Reflection answers

a. Container A takes the full grace period because its PID 1 (sleep) ignores
SIGTERM: the kernel does not apply the default action of an unhandled signal to
PID 1, so docker stop's SIGTERM does nothing, the grace expires, and only then
does SIGKILL end it - exit 137 (128 + 9). This is the real cause of the famous
"my container always takes ten seconds to stop": it is not working, it is
ignoring the polite request because nobody at PID 1 is listening.

b. Container B stops at once because --init puts tini at PID 1, and tini is
written to handle SIGTERM and forward it to its child. Now sleep, no longer PID 1,
receives SIGTERM and its default action terminates it immediately - a clean exit
143 (128 + 15). The fix was not to change the application but to give it a proper
init: --init (tini) as PID 1, which also reaps zombies. One flag turns a
ten-second SIGKILL into an instant, orderly shutdown.

c. The exit codes are a diagnosis you will use in chapter 26: 137 means SIGKILL
(here the grace timeout, in chapter 3 the OOM killer), 143 means a clean SIGTERM.
Designing for SIGTERM matters because a process killed with SIGKILL has no chance
to clean up: a database that receives SIGTERM closes its transactions and does not
corrupt data; the same database SIGKILLed can leave the file half-written.
Graceful shutdown is not a nicety - it is data safety.
