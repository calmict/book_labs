#!/usr/bin/env bash
set -euo pipefail

# Chapter 22 solution — the vault and the corridor: default allow, the
# inversion, the nameplate door, and the vault that makes no calls.
# The policies only work if your CNI enforces them: the script checks.

DIR=$(cd "$(dirname "$0")" && pwd)

kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster — see chapter 7" >&2
  exit 1
}

cleanup() {
  kubectl delete namespace vault --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT
kubectl delete namespace vault --ignore-not-found >/dev/null 2>&1 || true
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
kubectl apply -f "$DIR/../start/pods.yaml"
kubectl -n vault wait --for=condition=Ready pod --all --timeout=180s >/dev/null
SAFE=$(kubectl -n vault get pod safe -o jsonpath='{.status.podIP}')
echo "app   -> safe: $(reach app "http://$SAFE:8080")"
echo "guest -> safe: $(reach guest "http://$SAFE:8080")"
echo "(jewels for everyone: nobody ever authorised anything — nobody ever forbade)"

echo
echo "== 2. The inversion (and the enforcement test) =="
kubectl apply -f "$DIR/../start/deny-all.yaml"
sleep 5
set +e
A=$(reach app "http://$SAFE:8080")
G=$(reach guest "http://$SAFE:8080")
set -e
if [ -z "$A" ] && [ -z "$G" ]; then
  echo "app and guest: timeout — the corridor is walled up, and your CNI"
  echo "REALLY enforces policies (the test everyone should run)"
else
  echo "ERROR: the jewels still flow — your CNI accepts NetworkPolicy" >&2
  echo "objects but does not enforce them (chapter 19 déjà vu)." >&2
  echo "On minikube: minikube start --cni=calico" >&2
  exit 1
fi

echo
echo "== 3. The door with a nameplate =="
kubectl apply -f "$DIR/allow-app.yaml"
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
echo "app   -> safe: gioielli (role=app, port 8080: the contract)"
set +e
G=$(reach guest "http://$SAFE:8080")
set -e
if [ -z "$G" ]; then
  echo "guest -> safe: still walled out (no role, no entry)"
else
  echo "WARNING: guest got through?!" >&2
fi

echo
echo "== 4. The vault makes no calls =="
kubectl apply -f "$DIR/no-exfiltration.yaml"
sleep 5
APP=$(kubectl -n vault get pod app -o jsonpath='{.status.podIP}')
set +e
OUT=$(reach safe "http://$APP:8080")
RC=$?
set -e
if [ "$RC" -ne 0 ] && [ -z "$OUT" ]; then
  echo "safe -> app: timeout — whoever cracks the vault carries nothing out"
  echo "(pro warning: an egress deny also blocks DNS; here we used raw IPs)"
else
  echo "WARNING: the vault can still call out" >&2
fi
