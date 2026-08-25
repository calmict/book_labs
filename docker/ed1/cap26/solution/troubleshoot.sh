#!/usr/bin/env bash
# cap26 solution - "the black box of the mute container": troubleshooting. A
# container exits silently with a non-zero code under a restart policy, crash-looping
# until the policy gives up. Three more cases distinguish an OOM kill, a missing
# command through a shell from a direct exec failure, and a shellless container that
# is inspected from a shared PID namespace. Throwaway resources, no daemon restart
# and no privileges.
set -euo pipefail

OUT="${1:?usage: troubleshoot.sh OUTPUT_DIR}"
mkdir -p "$OUT"
C="cap26-mute-$$"
OOM_C="cap26-oom-$$"
SHELL_C="cap26-shell-$$"
DIRECT_C="cap26-direct-$$"
SHELLLESS_C="cap26-shellless-$$"
SHELLLESS_IMAGE="cap26-shellless-image-$$"
cleanup() {
  docker rm -f "$C" "$OOM_C" "$SHELL_C" "$DIRECT_C" "$SHELLLESS_C" >/dev/null 2>&1 || true
  docker image rm -f "$SHELLLESS_IMAGE" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# exits silently with code 42, under a restart policy -> crash loop, then gives up
docker run -d --name "$C" --restart on-failure:3 busybox sh -c 'exit 42' >/dev/null
sleep 6   # let the crash loop finish

# TODO 1 (26.1): read the container's logs (it is mute - empty).
logs=$(docker logs "$C" 2>&1)

# TODO 2 (26.2): read the exit code from inspect (the real diagnosis).
exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$C")

# TODO 3 (26.3): read how many times it restarted and its final status.
restart_count=$(docker inspect -f '{{.RestartCount}}' "$C")
status=$(docker inspect -f '{{.State.Status}}' "$C")

# TODO 4 (26.4): read both exit code 137 and OOMKilled from inspect.
docker run -d --name "$OOM_C" --memory 16m busybox \
  sh -c 'dd if=/dev/zero of=/dev/null bs=64M' >/dev/null
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  [ "$(docker inspect -f '{{.State.Running}}' "$OOM_C")" = "false" ] && break
  sleep 0.2
done
oom_exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$OOM_C")
oom_killed=$(docker inspect -f '{{.State.OOMKilled}}' "$OOM_C")

# TODO 5 (26.4): compare shell command-not-found with a direct exec failure.
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

# TODO 6 (26.4): inspect a shellless container through a shared PID namespace.
cat >"$OUT/Dockerfile.shellless" <<'EOF'
FROM busybox:1.36.1-uclibc AS source
FROM scratch
COPY --from=source /bin/busybox /sleep
ENTRYPOINT ["/sleep", "30"]
EOF
docker build -q -t "$SHELLLESS_IMAGE" -f "$OUT/Dockerfile.shellless" "$OUT" >/dev/null
docker run -d --name "$SHELLLESS_C" "$SHELLLESS_IMAGE" >/dev/null
shellless_exec_code=0
docker exec "$SHELLLESS_C" sh >"$OUT/shellless.stdout" 2>"$OUT/shellless.stderr" || shellless_exec_code=$?
docker run --rm --pid="container:$SHELLLESS_C" busybox ps >"$OUT/processes.txt"

{
  echo "logs_len=$(printf '%s' "$logs" | wc -c)"
  echo "exit_code=$exit_code"
  echo "restart_count=$restart_count"
  echo "status=$status"
  echo "oom_exit_code=$oom_exit_code"
  echo "oom_killed=$oom_killed"
  echo "shell_run_code=$shell_run_code"
  echo "shell_exit_code=$shell_exit_code"
  echo "shell_error=$shell_error"
  echo "direct_start_code=$direct_start_code"
  echo "direct_status=$direct_status"
  echo "direct_error=$direct_error"
  echo "shellless_exec_code=$shellless_exec_code"
} > "$OUT/diag.txt"
