#!/usr/bin/env bash
set -Eeuo pipefail

namespaces=(labcap28a labcap28b labcap28c labcap28fabric)
host_links=(labcap28a0 labcap28b0 labcap28a1 labcap28fa labcap28b1 labcap28fb labcap28c1 labcap28fc labcap28br)
created_namespaces=()

cleanup() {
    local status=$?
    trap - EXIT INT TERM
    for namespace in "${created_namespaces[@]}"; do
        ip netns del "$namespace" >/dev/null 2>&1 || true
    done
    for interface_name in "${host_links[@]}"; do
        ip link del "$interface_name" >/dev/null 2>&1 || true
    done
    printf 'CLEANUP namespaces=removed bridge=removed veth_devices=removed\n'
    exit "$status"
}
trap cleanup EXIT INT TERM

for command_name in ip bridge ping awk grep; do
    command -v "$command_name" >/dev/null || {
        printf 'ERROR missing command: %s\n' "$command_name" >&2
        exit 1
    }
done

if (( EUID != 0 )); then
    printf 'SKIP network construction requires root; rerun this script with sudo\n'
    exit 0
fi

printf 'STEP 1 collision checks\n'
for namespace in "${namespaces[@]}"; do
    if ip netns list | awk '{print $1}' | grep -Fxq "$namespace"; then
        printf 'ERROR namespace already exists: %s\n' "$namespace" >&2
        exit 1
    fi
    printf 'NAME_FREE namespace=%s\n' "$namespace"
done
for interface_name in "${host_links[@]}"; do
    if ip link show "$interface_name" >/dev/null 2>&1; then
        printf 'ERROR interface already exists: %s\n' "$interface_name" >&2
        exit 1
    fi
    printf 'NAME_FREE interface=%s\n' "$interface_name"
done

for namespace in labcap28a labcap28b; do
    ip netns add "$namespace"
    created_namespaces+=("$namespace")
    ip -n "$namespace" link set lo up
done

printf 'STEP 2 direct veth pair\n'
ip link add labcap28a0 type veth peer name labcap28b0
ip link set labcap28a0 netns labcap28a
ip link set labcap28b0 netns labcap28b
ip -n labcap28a address add 10.28.1.1/30 dev labcap28a0
ip -n labcap28b address add 10.28.1.2/30 dev labcap28b0
ip -n labcap28a link set labcap28a0 up
ip -n labcap28b link set labcap28b0 up
route_direct=$(ip netns exec labcap28a ip route get 10.28.1.2)
printf 'ROUTE_DIRECT=%s\n' "$route_direct"
[[ "$route_direct" == *'dev labcap28a0'* && "$route_direct" == *'src 10.28.1.1'* ]]
ip netns exec labcap28a ping -c 2 -W 1 10.28.1.2
ip -n labcap28a link del labcap28a0

printf 'STEP 3 three endpoints on a bridge\n'
for namespace in labcap28c labcap28fabric; do
    ip netns add "$namespace"
    created_namespaces+=("$namespace")
    ip -n "$namespace" link set lo up
done
ip -n labcap28fabric link add labcap28br type bridge
ip -n labcap28fabric link set labcap28br up

connect_endpoint() {
    local endpoint_namespace=$1
    local endpoint_interface=$2
    local fabric_interface=$3
    local address=$4
    ip link add "$endpoint_interface" type veth peer name "$fabric_interface"
    ip link set "$endpoint_interface" netns "$endpoint_namespace"
    ip link set "$fabric_interface" netns labcap28fabric
    ip -n "$endpoint_namespace" address add "$address" dev "$endpoint_interface"
    ip -n "$endpoint_namespace" link set "$endpoint_interface" up
    ip -n labcap28fabric link set "$fabric_interface" master labcap28br
    ip -n labcap28fabric link set "$fabric_interface" up
}

connect_endpoint labcap28a labcap28a1 labcap28fa 10.28.2.11/24
connect_endpoint labcap28b labcap28b1 labcap28fb 10.28.2.12/24
connect_endpoint labcap28c labcap28c1 labcap28fc 10.28.2.13/24

ip netns exec labcap28fabric bridge link show
printf 'FDB_BEFORE\n'
ip netns exec labcap28fabric bridge fdb show br labcap28br
route_bridge=$(ip netns exec labcap28a ip route get 10.28.2.13)
printf 'ROUTE_BRIDGE=%s\n' "$route_bridge"
[[ "$route_bridge" == *'dev labcap28a1'* && "$route_bridge" == *'src 10.28.2.11'* ]]
ip netns exec labcap28a ping -c 2 -W 1 10.28.2.13
ip netns exec labcap28c ping -c 2 -W 1 10.28.2.12
printf 'FDB_AFTER\n'
ip netns exec labcap28fabric bridge fdb show br labcap28br
