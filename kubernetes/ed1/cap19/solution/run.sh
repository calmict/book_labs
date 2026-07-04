#!/usr/bin/env bash
set -euo pipefail

# Chapter 19 solution — the door and the doorman.
# Requires kind, Docker, curl on the host, network access (ingress-nginx
# gets downloaded) and a free port 8081 on the host.

CLUSTER=book-labs-ingress
NGINX_MANIFEST=https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.14.0/deploy/static/provider/kind/deploy.yaml
DIR=$(cd "$(dirname "$0")" && pwd)

KC() { kubectl --context "kind-$CLUSTER" "$@"; }

CREATED=0
PREV_CTX=$(kubectl config current-context 2>/dev/null || true)

cleanup() {
  if [ "$CREATED" -eq 1 ]; then
    kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
    if [ -n "$PREV_CTX" ] && [ "$PREV_CTX" != "kind-$CLUSTER" ]; then
      kubectl config use-context "$PREV_CTX" >/dev/null 2>&1 || true
    fi
  fi
}
trap cleanup EXIT

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "== 1. Reusing the existing $CLUSTER cluster =="
else
  echo "== 1. Creating the cluster with the mapped door (host 8081) =="
  kind create cluster --config "$DIR/../start/kind-ingress.yaml" --wait 180s
  CREATED=1
fi
KC wait --for=condition=Ready nodes --all --timeout=180s >/dev/null
KC apply -f "$DIR/../start/apps.yaml"
KC rollout status deployment/uno --timeout=180s >/dev/null
KC rollout status deployment/due --timeout=180s >/dev/null
KC get svc uno due

echo
echo "== 2. The written request, with no doorman =="
KC apply -f "$DIR/ingress.yaml"
KC get ingress labs
set +e
OUT=$(curl -s -m 3 http://localhost:8081 2>&1)
RC=$?
set -e
if [ "$RC" -ne 0 ]; then
  echo "(curl refused, ADDRESS empty: rules on file, nobody enforcing them —"
  echo " an object is a wish, a controller is who grants it)"
else
  echo "note: something answered on 8081 already: $OUT"
fi

echo
echo "== 3. The doorman arrives (ingress-nginx, pinned) =="
KC apply -f "$NGINX_MANIFEST" >/dev/null
echo -n "waiting for the controller "
waited=0
until KC get pod -n ingress-nginx -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | grep -q .; do
  echo -n "."
  sleep 5
  waited=$((waited + 5))
  if [ "$waited" -ge 180 ]; then
    echo " timeout (pod never appeared)" >&2
    exit 1
  fi
done
KC wait -n ingress-nginx --for=condition=Ready pod \
  -l app.kubernetes.io/component=controller --timeout=300s >/dev/null
echo " ready"
KC get pods -n ingress-nginx

echo
echo "== 4. One door, two destinations =="
check_host() {
  local host=$1 expect=$2 waited=0 out
  while true; do
    out=$(curl -s -m 3 -H "Host: $host" http://localhost:8081 || true)
    if [ "$out" = "$expect" ]; then
      echo "$host -> $out"
      return 0
    fi
    sleep 5
    waited=$((waited + 5))
    if [ "$waited" -ge 120 ]; then
      echo "timeout: $host answered '$out' instead of '$expect'" >&2
      return 1
    fi
  done
}
check_host uno.labs.local app-uno
check_host due.labs.local app-due
CODE=$(curl -s -m 3 -o /dev/null -w '%{http_code}' http://localhost:8081)
echo "no Host header -> HTTP $CODE (strangers get the default backend)"
KC get ingress labs

echo
echo "== 5. The anatomy, in the doorman's own words =="
KC logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=4
echo
echo "(host port 8081 -> node port 80 -> controller pod -> L7 decision on"
echo " the Host header -> the app's Service -> the pod: chapters 18 and 6"
echo " under a layer-7 hat)"
