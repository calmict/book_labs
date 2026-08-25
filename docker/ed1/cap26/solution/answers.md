# Chapter 26 — Answers

## The completed TODOs

**TODO 1 (26.1) — the container's logs:**

    logs=$(docker logs "$C" 2>&1)

**TODO 2 (26.2) — the exit code:**

    exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$C")

**TODO 3 (26.3) — the restart counter and final status:**

    restart_count=$(docker inspect -f '{{.RestartCount}}' "$C")
    status=$(docker inspect -f '{{.State.Status}}' "$C")

**TODO 4 (26.4) — exit 137 and the OOM confirmation:**

    docker run -d --name "$OOM_C" --memory 16m busybox \
      sh -c 'dd if=/dev/zero of=/dev/null bs=64M' >/dev/null
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
      [ "$(docker inspect -f '{{.State.Running}}' "$OOM_C")" = "false" ] && break
      sleep 0.2
    done
    oom_exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$OOM_C")
    oom_killed=$(docker inspect -f '{{.State.OOMKilled}}' "$OOM_C")

**TODO 5 (26.4) — shell command-not-found versus direct exec:**

    shell_run_code=0
    docker run --name "$SHELL_C" busybox sh -c 'cap26-command-does-not-exist' \
      >"$OUT/shell.stdout" 2>"$OUT/shell.stderr" || shell_run_code=$?
    shell_exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$SHELL_C")
    shell_error=$(docker inspect -f '{{.State.Error}}' "$SHELL_C")
    docker create --name "$DIRECT_C" busybox cap26-command-does-not-exist >/dev/null
    direct_start_code=0
    docker start "$DIRECT_C" >"$OUT/direct.stdout" 2>"$OUT/direct.stderr" || direct_start_code=$?
    direct_status=$(docker inspect -f '{{.State.Status}}' "$DIRECT_C")
    direct_error=$(docker inspect -f '{{.State.Error}}' "$DIRECT_C")

**TODO 6 (26.4) — process inspection without a shell:**

    cat >"$OUT/Dockerfile.shellless" <<'EOF'
    FROM busybox:1.36.1-uclibc AS source
    FROM scratch
    COPY --from=source /bin/busybox /sleep
    ENTRYPOINT ["/sleep", "30"]
    EOF
    docker build -q -t "$SHELLLESS_IMAGE" -f "$OUT/Dockerfile.shellless" "$OUT" >/dev/null
    docker run -d --name "$SHELLLESS_C" "$SHELLLESS_IMAGE" >/dev/null
    shellless_exec_code=0
    docker exec "$SHELLLESS_C" sh >"$OUT/shellless.stdout" \
      2>"$OUT/shellless.stderr" || shellless_exec_code=$?
    docker run --rm --pid="container:$SHELLLESS_C" busybox ps >"$OUT/processes.txt"

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

**c. Why are neither 137 nor 127 enough on their own?**

Exit 137 says that the process received SIGKILL, but not who sent it or why. The
State.OOMKilled flag is the independent evidence that connects this SIGKILL to the
container exceeding its memory limit. Without that flag, an operator or another mechanism
could have sent the same signal. The remedy is to fix excessive allocation and set a limit
from measured demand, rather than treating every 137 as proof that the limit is too low.

Exit 127 belongs to the shell's command-not-found convention when a shell actually starts.
In that case State.Error is empty because the runtime did its job and the shell chose the
exit code. With a missing direct executable, no container process starts: the state remains
created and State.Error records the runtime failure. The remedy is to correct CMD,
ENTRYPOINT or PATH, or to invoke an existing shell explicitly when shell behaviour is
required.

The shellless target supplies another counterproof: docker exec cannot run sh, but a
separate BusyBox helper sharing the target's PID namespace can list its sleep process. That
helper sees processes only. It does not see the target's filesystem and does not replace
nsenter across namespaces. In production, a purpose-built debug image keeps diagnostic
tools separate from the minimal application image; filesystem and other namespace work may
require different techniques and privileges.
