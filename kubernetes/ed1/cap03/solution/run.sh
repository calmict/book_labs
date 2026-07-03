#!/usr/bin/env bash
set -euo pipefail

# Chapter 3 solution — limit CPU and RAM by hand (cgroup v2).
# As root it runs the full sequence: CPU throttling, OOM kill, fork bouncer.
# As a regular user it degrades to the memory and pids parts through a
# systemd user scope (the cpu controller is not delegated to users).

if [ "$(stat -fc %T /sys/fs/cgroup)" != "cgroup2fs" ]; then
  echo "ERROR: cgroup v2 not mounted at /sys/fs/cgroup (see the WSL2 note in the brief)" >&2
  exit 1
fi

# Average % of one core used by a PID over 3 seconds (100 ticks = 1 second).
cpu_pct() {
  local t1 t2
  t1=$(awk '{print $14+$15}' "/proc/$1/stat")
  sleep 3
  t2=$(awk '{print $14+$15}' "/proc/$1/stat")
  echo $(( (t2 - t1) / 3 ))
}

if [ "$(id -u)" -eq 0 ]; then
  CG=/sys/fs/cgroup/lab-cap03
  LOOP=""
  cleanup() {
    [ -n "$LOOP" ] && kill "$LOOP" 2>/dev/null || true
    if [ -d "$CG" ]; then
      while read -r p; do kill -9 "$p" 2>/dev/null || true; done < "$CG/cgroup.procs"
      sleep 1
      rmdir "$CG" 2>/dev/null || true
    fi
  }
  trap cleanup EXIT

  mkdir "$CG"
  # Make sure the cage inherited the controllers we need (on a normal systemd
  # host they are already enabled in the root cgroup's subtree_control).
  for c in cpu memory pids; do
    grep -qw "$c" "$CG/cgroup.controllers" ||
      echo "+$c" > /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || true
  done
  echo "== Controllers inherited by the cage =="
  cat "$CG/cgroup.controllers"
  grep -qw cpu "$CG/cgroup.controllers" || {
    echo "ERROR: cpu controller not available in $CG" >&2
    exit 1
  }

  echo
  echo "== CPU slows down: free vs caged =="
  sh -c 'while :; do :; done' &
  LOOP=$!
  echo "free:  ~$(cpu_pct "$LOOP")% of one core"
  echo "20000 100000" > "$CG/cpu.max"
  echo "$LOOP" > "$CG/cgroup.procs"
  sleep 2
  echo "caged: ~$(cpu_pct "$LOOP")% of one core (cpu.max = 20000 100000)"
  grep -E 'nr_throttled|throttled_usec' "$CG/cpu.stat"
  kill "$LOOP"
  wait "$LOOP" 2>/dev/null || true
  LOOP=""

  echo
  echo "== Memory kills: the OOM in action =="
  echo 64M > "$CG/memory.max"
  [ -f "$CG/memory.swap.max" ] && echo 0 > "$CG/memory.swap.max"
  set +e
  sh -c "echo \$\$ > $CG/cgroup.procs; head -c 200M /dev/zero | tail"
  rc=$?
  set -e
  echo "glutton exit code: $rc (137 = killed by SIGKILL)"
  echo "--- memory.events ---"
  cat "$CG/memory.events"
  if [ -f "$CG/memory.peak" ]; then
    echo "--- memory.peak (bytes) ---"
    cat "$CG/memory.peak"
  fi

  echo
  echo "== Pids: the fork bouncer =="
  echo 5 > "$CG/pids.max"
  set +e
  timeout 20 sh -c "echo \$\$ > $CG/cgroup.procs; for i in 1 2 3 4 5 6 7 8; do sleep 2 & done; wait" 2>&1 | tail -4
  set -e
  echo "--- pids.events ---"
  cat "$CG/pids.events"
else
  echo "(not root: the cpu controller is not delegated to users — running the"
  echo " memory and pids parts through a systemd user scope; use sudo for the"
  echo " CPU throttling part)"
  command -v systemd-run >/dev/null 2>&1 || {
    echo "ERROR: systemd-run not found" >&2
    exit 1
  }

  echo
  echo "== Memory kills: the OOM in action (rootless) =="
  set +e
  systemd-run --user --scope --quiet -p MemoryMax=64M -p MemorySwapMax=0 -- \
    sh -c 'head -c 200M /dev/zero | tail'
  rc=$?
  set -e
  echo "glutton exit code: $rc (137 = killed by SIGKILL)"

  echo
  echo "== Pids: the fork bouncer (rootless) =="
  set +e
  timeout 20 systemd-run --user --scope --quiet -p TasksMax=5 -- \
    sh -c 'for i in 1 2 3 4 5 6 7 8; do sleep 2 & done; wait' 2>&1 | tail -4
  set -e
fi

echo
echo "Same accountant, two different verdicts: CPU gets throttled (slower,"
echo "never killed), memory gets the SIGKILL. That is exactly the difference"
echo "between a CPU limit and a memory limit in a Kubernetes Pod."
