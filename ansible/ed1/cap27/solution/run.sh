#!/usr/bin/env bash
# cap27 - solution test. A node-less rolling update: a web farm of local hosts and
# a load balancer whose pool membership is a shared ledger file, so the rollout is
# visible and checkable. Proves three things:
#   1. rolling choreography - every host is drained, updated and re-enabled, and
#      NEVER more than one wave (serial=2) is out of the pool at once;
#   2. the emergency brake - a failing wave stops the rollout before it reaches the
#      rest of the farm (max_fail_percentage);
#   3. why waves matter - widen the wave to the whole farm and the whole pool goes
#      down at once, the outage rolling updates exist to avoid.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
VENV="$WORK/venv"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

python3 -m venv "$VENV"
# shellcheck disable=SC1091
. "$VENV/bin/activate"
pip -q install -r "$HERE/requirements.txt"

FARM=6
SERIAL=2

AP() { ansible-playbook -i "$HERE/inventory.ini" "$@"; }

# From a ledger, print: "<drains> <updates> <enables> <max-concurrently-drained> <malformed>"
summ() {
  python3 - "$1" <<'PY'
import sys
lines = [l for l in open(sys.argv[1]) if l.strip()]
mal = sum(len(l.split()) != 3 for l in lines)
d = sum(l.split()[1] == "DRAIN" for l in lines)
u = sum(l.split()[1] == "UPDATED" for l in lines)
e = sum(l.split()[1] == "ENABLE" for l in lines)
depth = mx = 0
for l in sorted(lines, key=lambda x: int(x.split()[0])):
    ev = l.split()[1]
    depth += (ev == "DRAIN") - (ev == "ENABLE")
    mx = max(mx, depth)
print(d, u, e, mx, mal)
PY
}

# --- 1. the rolling choreography ---
L1="$WORK/healthy.log"; : > "$L1"
if ! AP "$HERE/site.yml" -e "ledger=$L1" >"$WORK/r1.out" 2>&1; then
  echo "UNEXPECTED: the healthy rolling update failed" >&2
  tail -15 "$WORK/r1.out" >&2; exit 1
fi
read -r d u e mx mal < <(summ "$L1")
if [ "$mal" -ne 0 ]; then
  echo "UNEXPECTED: $mal malformed ledger lines" >&2; exit 1
fi
if [ "$d" -ne "$FARM" ] || [ "$u" -ne "$FARM" ] || [ "$e" -ne "$FARM" ]; then
  echo "UNEXPECTED: not all hosts drained/updated/re-enabled (D=$d U=$u E=$e, want $FARM)" >&2
  echo "  did you add the post_tasks re-enable step (TODO 2)?" >&2; exit 1
fi
if [ "$mx" -ne "$SERIAL" ]; then
  echo "UNEXPECTED: at peak $mx nodes were out of the pool, expected serial=$SERIAL" >&2
  echo "  did you set serial (TODO 1)?" >&2; exit 1
fi
echo "OK 1 - rolling choreography: all $FARM nodes drained, updated and re-enabled; never more than $SERIAL out of the pool at once"

# --- 2. the emergency brake ---
L2="$WORK/brake.log"; : > "$L2"
set +e
AP "$HERE/site.yml" -e "ledger=$L2" -e '{"fail_hosts":["web1"]}' >"$WORK/r2.out" 2>&1
brake_rc=$?
set -e
if [ "$brake_rc" -eq 0 ]; then
  echo "UNEXPECTED: a failing wave did NOT stop the rollout" >&2
  echo "  did you set max_fail_percentage (TODO 3)?" >&2; exit 1
fi
drained2=$(grep -c ' DRAIN ' "$L2" || true)
if [ "$drained2" -gt "$SERIAL" ]; then
  echo "UNEXPECTED: the brake let the rollout past the first wave ($drained2 nodes drained)" >&2; exit 1
fi
echo "OK 2 - emergency brake: a failing wave stopped the rollout after the first batch ($drained2 node(s) touched, the rest of the farm untouched)"

# --- 3. why waves matter: widen the wave to the whole farm -> outage ---
sed 's/^  serial: .*/  serial: '"$FARM"'/' "$HERE/site.yml" > "$WORK/allatonce.yml"
L3="$WORK/allatonce.log"; : > "$L3"
AP "$WORK/allatonce.yml" -e "ledger=$L3" >"$WORK/r3.out" 2>&1
read -r _ _ _ mx3 _ < <(summ "$L3")
if [ "$mx3" -ne "$FARM" ]; then
  echo "UNEXPECTED: widening the wave did not take the whole farm down (peak $mx3)" >&2; exit 1
fi
echo "OK 3 - without waves the whole farm ($mx3 nodes) is drained at once: the outage serial exists to prevent"

echo
echo "ALL CHECKS PASSED"
