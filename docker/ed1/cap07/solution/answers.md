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

TODO 4 (7.5) - start five short-lived orphaned children, wait for them to exit,
and count zombie states in /proc. Run the function without init and with tini:

    count_zombies() {  # $1 = suffix ; $2.. = extra docker run flags
      local n="${NAME}-$1"; shift
      docker run -d "$@" --name "$n" busybox sh -c \
        'for i in 1 2 3 4 5; do sh -c "sleep 1 &"; done; sleep 300' >/dev/null
      sleep 4
      docker exec "$n" sh -c '
        count=0
        for stat in /proc/[0-9]*/stat; do
          read -r pid comm state rest < "$stat" || continue
          [ "$state" = Z ] && count=$((count + 1))
        done
        echo "$count"
      '
      docker rm -f "$n" >/dev/null
    }

    zombies_noinit=$(count_zombies z-noinit)
    zombies_init=$(count_zombies z-init --init)

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
