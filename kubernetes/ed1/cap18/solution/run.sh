#!/usr/bin/env bash
set -euo pipefail

# Chapter 18 solution — the address that does not exist.
# Needs a cluster whose node is a Docker container (kind, or minikube on
# the docker driver): step 3 reads the node's iptables.

DIR=$(cd "$(dirname "$0")" && pwd)

kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster — see chapter 7" >&2
  exit 1
}
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
docker exec "$NODE" true 2>/dev/null || {
  echo "ERROR: cannot enter node $NODE with docker exec (this run.sh" >&2
  echo " needs kind, or minikube with the docker driver)" >&2
  exit 1
}

cleanup() {
  kubectl delete -f "$DIR/helpdesk.yaml" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete pod client --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

echo "== 1. The problem: direct numbers die with their owners =="
kubectl apply -f "$DIR/helpdesk.yaml"
kubectl rollout status deployment/helpdesk --timeout=180s >/dev/null
kubectl get pods -l app=helpdesk -o wide
PODIP=$(kubectl get pods -l app=helpdesk -o jsonpath='{.items[0].metadata.name} {.items[0].status.podIP}')
VICTIM=${PODIP% *}
OLDIP=${PODIP#* }
kubectl run client --image=busybox:stable -- sleep infinity >/dev/null
kubectl wait --for=condition=Ready pod/client --timeout=180s >/dev/null
echo "--- calling $VICTIM at its direct number $OLDIP ---"
kubectl exec client -- wget -qO- "http://$OLDIP:8080"
kubectl delete pod "$VICTIM" >/dev/null
kubectl rollout status deployment/helpdesk --timeout=180s >/dev/null
echo "--- $VICTIM is dead; its direct number too ---"
set +e
kubectl exec client -- wget -T 3 -qO- "http://$OLDIP:8080" 2>&1 | tail -1
set -e
kubectl get pods -l app=helpdesk -o wide

echo
echo "== 2. The switchboard: one stable address, voices alternating =="
kubectl get service helpdesk
VOICES=$(for _ in 1 2 3 4 5 6 7 8 9 10; do
  kubectl exec client -- wget -qO- http://helpdesk
done | sort | uniq -c)
echo "$VOICES"
UNIQUE=$(echo "$VOICES" | wc -l)
if [ "$UNIQUE" -ge 2 ]; then
  echo "(ten calls, $UNIQUE distinct voices: the balancing is real)"
else
  echo "WARNING: only one voice answered ten calls" >&2
fi

echo
echo "== 3. The investigation: that IP does not exist =="
CIP=$(kubectl get svc helpdesk -o jsonpath='{.spec.clusterIP}')
echo "ClusterIP: $CIP — searching it on the node's interfaces..."
if docker exec "$NODE" ip addr | grep -q "$CIP"; then
  echo "WARNING: the ClusterIP is on an interface?!" >&2
else
  echo "(no interface anywhere owns it — yet wget works)"
fi
echo "--- the trick, where chapter 6 taught you to look ---"
RULES=$(docker exec "$NODE" iptables-save | grep helpdesk || true)
if [ -n "$RULES" ]; then
  echo "$RULES" | head -8
  echo "(KUBE-SVC with --probability: netfilter's coin; KUBE-SEP with the"
  echo " DNAT to the pods' real IPs — the ClusterIP is a rewrite, not a place)"
else
  echo "(no iptables rules found: this kube-proxy speaks nftables — same"
  echo " trick, different dialect: docker exec $NODE nft list ruleset)"
fi

echo
echo "== 4. Who updates the phonebook: EndpointSlice =="
kubectl get endpointslices -l kubernetes.io/service-name=helpdesk -o wide
kubectl scale deployment helpdesk --replicas=3 >/dev/null
kubectl rollout status deployment/helpdesk --timeout=180s >/dev/null
echo "--- scaled to 3: the phonebook followed ---"
kubectl get endpointslices -l kubernetes.io/service-name=helpdesk -o wide

echo
echo "== 5. The only truly stable thing: the name =="
kubectl exec client -- nslookup helpdesk.default.svc.cluster.local 2>&1 | tail -3
echo "(it resolves to the ClusterIP, not to the pods: compare with chapter"
echo " 16's headless diary — stability hierarchy: pod IP < ClusterIP < name)"
