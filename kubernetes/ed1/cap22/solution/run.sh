#!/usr/bin/env bash
set -euo pipefail

# Chapter 22 solution test. Proves default allow, CNI enforcement of an
# ingress default deny, a label-and-port exception, and an egress deny.
# Uses one throwaway namespace and requires no host privileges.

DIR=$(cd "$(dirname "$0")" && pwd)

command -v kubectl >/dev/null || { echo "ERROR: kubectl is required" >&2; exit 1; }
kubectl get nodes >/dev/null || { echo "ERROR: no reachable cluster" >&2; exit 1; }
echo "PRECHECK cluster reachable; NetworkPolicy enforcement will be measured"

cleanup() {
  kubectl delete namespace vault --ignore-not-found --wait=true >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup
echo -n "making sure the vault namespace is gone "
waited=0
while kubectl get namespace vault >/dev/null 2>&1; do
  echo -n "."
  sleep 3
  waited=$((waited + 3))
  if [ "$waited" -ge 120 ]; then
    echo " timeout" >&2
    exit 1
  fi
done
echo

reach() { # $1 = from pod, $2 = target url; prints the body or FAILS
  kubectl -n vault exec "$1" -- wget -T 3 -qO- "$2" 2>/dev/null
}

echo "== 1. The open corridor (default allow) =="
kubectl create namespace vault >/dev/null
kubectl apply -f "$DIR/../start/pods.yaml" >/dev/null
kubectl -n vault wait --for=condition=Ready pod --all --timeout=180s >/dev/null
SAFE=$(kubectl -n vault get pod safe -o jsonpath='{.status.podIP}')
if [ "$(reach app "http://$SAFE:8080")" != gioielli ] || [ "$(reach guest "http://$SAFE:8080")" != gioielli ]; then
  echo "UNEXPECTED: default-allow traffic did not reach the safe" >&2; exit 1
fi
echo "OK 1 - default allow lets both app and guest reach the safe"

echo
echo "== 2. The inversion (and the enforcement test) =="
kubectl apply -f "$DIR/deny-all.yaml" >/dev/null
sleep 5
set +e
A=$(reach app "http://$SAFE:8080")
G=$(reach guest "http://$SAFE:8080")
set -e
if [ -z "$A" ] && [ -z "$G" ]; then
  echo "OK 2 - the gate bites: ingress default deny blocks both clients and proves CNI enforcement"
else
  echo "ERROR: the jewels still flow — your CNI accepts NetworkPolicy" >&2
  echo "objects but does not enforce them (chapter 19 déjà vu)." >&2
  echo "On minikube: minikube start --cni=calico" >&2
  exit 1
fi

echo
echo "== 3. The door with a nameplate =="
kubectl apply -f "$DIR/allow-app.yaml" >/dev/null
echo -n "waiting for the door "
waited=0
until [ "$(reach app "http://$SAFE:8080" || true)" = "gioielli" ]; do
  echo -n "."
  sleep 3
  waited=$((waited + 3))
  if [ "$waited" -ge 60 ]; then
    echo " timeout" >&2
    exit 1
  fi
done
echo
app_result=$(reach app "http://$SAFE:8080")
set +e
G=$(reach guest "http://$SAFE:8080")
set -e
if [ "$app_result" != gioielli ] || [ -n "$G" ]; then
  echo "UNEXPECTED: the label-and-port contract was not enforced" >&2; exit 1
fi
echo "OK 3 - role=app reaches TCP 8080 while the unlabelled guest remains blocked"

echo
echo "== 4. The vault makes no calls =="
kubectl apply -f "$DIR/no-exfiltration.yaml" >/dev/null
sleep 5
APP=$(kubectl -n vault get pod app -o jsonpath='{.status.podIP}')
set +e
OUT=$(reach safe "http://$APP:8080")
RC=$?
set -e
if [ "$RC" -ne 0 ] && [ -z "$OUT" ]; then
  echo "OK 4 - the egress gate bites: the safe cannot call the app by raw IP"
else
  echo "UNEXPECTED: the vault can still call out" >&2; exit 1
fi
echo
echo "ALL CHECKS PASSED"
