#!/usr/bin/env bash
set -euo pipefail

# Chapter 18 solution: ephemeral Pod addresses, stable Service routing,
# EndpointSlice reconciliation, node dataplane rules, and cluster DNS.

DIR=$(cd "$(dirname "$0")" && pwd)
NS=book-labs-cap18

cleanup() {
  kubectl delete namespace "$NS" --ignore-not-found --wait=true >/dev/null 2>&1 || true
}
trap cleanup EXIT

kubectl get nodes >/dev/null
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
docker exec "$NODE" true >/dev/null 2>&1
echo "PRECHECK node $NODE is reachable through Docker"
proxy_config=$(kubectl -n kube-system get configmap kube-proxy -o jsonpath='{.data.config\.conf}' 2>/dev/null || true)
backend=$(printf '%s\n' "$proxy_config" | awk '$1 == "mode:" {gsub(/["'\'' ]/, "", $2); print $2; exit}')
if [ -z "$backend" ]; then
  backend=external
fi
echo "PRECHECK kube-proxy backend: $backend"
cleanup
kubectl create namespace "$NS" >/dev/null
kubectl -n "$NS" apply -f "$DIR/helpdesk.yaml" >/dev/null
kubectl -n "$NS" rollout status deployment/helpdesk --timeout=180s >/dev/null
kubectl -n "$NS" run client --image=busybox:stable -- sleep infinity >/dev/null
kubectl -n "$NS" wait --for=condition=Ready pod/client --timeout=180s >/dev/null

pair=$(kubectl -n "$NS" get pods -l app=helpdesk -o jsonpath='{.items[0].metadata.name} {.items[0].status.podIP}')
victim=${pair% *}
old_ip=${pair#* }
kubectl -n "$NS" exec client -- wget -qO- "http://$old_ip:8080" >/dev/null
kubectl -n "$NS" delete pod "$victim" --wait=true >/dev/null
kubectl -n "$NS" rollout status deployment/helpdesk --timeout=180s >/dev/null
new_ips=$(kubectl -n "$NS" get pods -l app=helpdesk -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}')
if printf '%s\n' "$new_ips" | grep -qx "$old_ip"; then
  echo "ERROR: deleted Pod address is still assigned" >&2
  exit 1
fi
echo "OK 1 - a replacement Pod received a different ephemeral address"

cip=$(kubectl -n "$NS" get service helpdesk -o jsonpath='{.spec.clusterIP}')
voices=$(for _ in 1 2 3 4 5 6 7 8 9 10; do kubectl -n "$NS" exec client -- wget -qO- http://helpdesk; done | sort -u | wc -l)
if [ "$voices" -lt 2 ]; then
  echo "ERROR: repeated Service calls did not reach both backends" >&2
  exit 1
fi
echo "OK 2 - one ClusterIP balanced repeated calls across both operators"

if docker exec "$NODE" ip addr | grep -Fq "$cip"; then
  echo "ERROR: ClusterIP unexpectedly belongs to a node interface" >&2
  exit 1
fi
case "$backend" in
  iptables)
    rules=$(docker exec "$NODE" iptables-save 2>/dev/null || true)
    if ! printf '%s\n' "$rules" | grep -F "$cip" | grep -Fq 'KUBE-SVC'; then
      echo "ERROR: ClusterIP is absent from kube-proxy's iptables rules" >&2
      exit 1
    fi
    printf '%s\n' "$rules" | grep -F "$cip" | head -1
    echo "OK 3 - the ClusterIP is virtual and present in kube-proxy's iptables rules"
    ;;
  nftables)
    rules=$(docker exec "$NODE" nft list table ip kube-proxy 2>/dev/null || true)
    if ! printf '%s\n' "$rules" | grep -Fq "$cip"; then
      echo "ERROR: ClusterIP is absent from kube-proxy's nftables table" >&2
      exit 1
    fi
    printf '%s\n' "$rules" | grep -F "$cip" | head -1
    echo "OK 3 - the ClusterIP is virtual and present in kube-proxy's nftables table"
    ;;
  ipvs)
    rules=$(docker exec "$NODE" ipvsadm -Ln 2>/dev/null || true)
    if ! printf '%s\n' "$rules" | grep -Fq "$cip"; then
      echo "ERROR: ClusterIP is absent from kube-proxy's IPVS table" >&2
      exit 1
    fi
    printf '%s\n' "$rules" | grep -F "$cip" | head -1
    echo "OK 3 - the ClusterIP is virtual and present in kube-proxy's IPVS table"
    ;;
  *)
    echo "SKIP 3 - kube-proxy mode is not declared; the Service may use a replacement dataplane"
    ;;
esac

before=$(kubectl -n "$NS" get endpointslice -l kubernetes.io/service-name=helpdesk -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{"\n"}{end}' | sort -u | wc -l)
kubectl -n "$NS" scale deployment helpdesk --replicas=3 >/dev/null
kubectl -n "$NS" rollout status deployment/helpdesk --timeout=180s >/dev/null
after=$(kubectl -n "$NS" get endpointslice -l kubernetes.io/service-name=helpdesk -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{"\n"}{end}' | sort -u | wc -l)
if [ "$before" -ne 2 ] || [ "$after" -ne 3 ]; then
  echo "ERROR: EndpointSlice did not follow the scale from two to three" >&2
  exit 1
fi
echo "OK 4 - EndpointSlice reconciled from two ready addresses to three"

resolved=$(kubectl -n "$NS" exec client -- nslookup helpdesk.book-labs-cap18.svc.cluster.local)
if ! printf '%s\n' "$resolved" | grep -Fq "$cip"; then
  echo "ERROR: CoreDNS did not resolve the Service name to its ClusterIP" >&2
  exit 1
fi
kubectl -n "$NS" delete service helpdesk >/dev/null
if kubectl -n "$NS" exec client -- wget -T 3 -qO- http://helpdesk >/dev/null 2>&1; then
  echo "ERROR: Service traffic still passed after removing the Service" >&2
  exit 1
fi
echo "OK 5 - CoreDNS resolves the Service, and removing it closes the routing gate"
echo "ALL CHECKS PASSED"
