#!/usr/bin/env bash
set -Eeuo pipefail

firewall_namespace=labcap29
namespaces=(labcap29 labcap29client labcap29server)
host_links=(labcap29in labcap29cli labcap29out labcap29srv)
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
start_dir=$(cd -- "$script_dir/../start" && pwd)
work_dir=$(mktemp -d -t labcap29.XXXXXX)
created_namespaces=()
service_pid=

cleanup() {
    local status=$?
    trap - EXIT INT TERM
    if [[ -n "$service_pid" ]]; then
        kill "$service_pid" 2>/dev/null || true
        wait "$service_pid" 2>/dev/null || true
    fi
    for namespace in "${created_namespaces[@]}"; do
        ip netns del "$namespace" >/dev/null 2>&1 || true
    done
    for interface_name in "${host_links[@]}"; do
        ip link del "$interface_name" >/dev/null 2>&1 || true
    done
    rm -rf -- "$work_dir"
    printf 'CLEANUP namespaces=removed ruleset=removed veth_devices=removed processes=stopped\n'
    exit "$status"
}
trap cleanup EXIT INT TERM

for command_name in ip nft conntrack python3 sysctl awk grep; do
    command -v "$command_name" >/dev/null || {
        printf 'ERROR missing command: %s\n' "$command_name" >&2
        exit 1
    }
done

if (( EUID != 0 )); then
    printf 'SKIP firewall lab requires root; rerun this script with sudo\n'
    exit 0
fi

printf 'STEP 1 collision checks and isolated topology\n'
for namespace in "${namespaces[@]}"; do
    if ip netns list | awk '{print $1}' | grep -Fxq "$namespace"; then
        printf 'ERROR namespace already exists: %s\n' "$namespace" >&2
        exit 1
    fi
done
for interface_name in "${host_links[@]}"; do
    if ip link show "$interface_name" >/dev/null 2>&1; then
        printf 'ERROR interface already exists: %s\n' "$interface_name" >&2
        exit 1
    fi
done
for namespace in "${namespaces[@]}"; do
    ip netns add "$namespace"
    created_namespaces+=("$namespace")
    ip -n "$namespace" link set lo up
done

ip link add labcap29in type veth peer name labcap29cli
ip link set labcap29in netns labcap29
ip link set labcap29cli netns labcap29client
ip link add labcap29out type veth peer name labcap29srv
ip link set labcap29out netns labcap29
ip link set labcap29srv netns labcap29server

ip -n labcap29 address add 10.29.1.1/24 dev labcap29in
ip -n labcap29 link set labcap29in up
ip -n labcap29client address add 10.29.1.2/24 dev labcap29cli
ip -n labcap29client link set labcap29cli up
ip -n labcap29client route add default via 10.29.1.1
ip -n labcap29 address add 10.29.2.1/24 dev labcap29out
ip -n labcap29 link set labcap29out up
ip -n labcap29server address add 10.29.2.2/24 dev labcap29srv
ip -n labcap29server link set labcap29srv up
ip -n labcap29server route add default via 10.29.2.1
ip netns exec labcap29 sysctl -w net.ipv4.ip_forward=1

printf 'STEP 2 ruleset snapshot before load\n'
ip netns exec labcap29 nft list ruleset
printf 'STEP 2 load ruleset inside labcap29\n'
ip netns exec labcap29 nft -f "$start_dir/labcap29.nft"
printf 'STEP 2 ruleset snapshot after load\n'
ip netns exec labcap29 nft list ruleset

counter_packets() {
    local counter_name=$1
    local counter_output
    ip netns exec labcap29 nft list ruleset >/dev/null
    counter_output=$(ip netns exec labcap29 nft list counter inet labcap29filter "$counter_name")
    ip netns exec labcap29 nft list ruleset >/dev/null
    printf '%s\n' "$counter_output" | awk '
        /packets/ { for (i = 1; i <= NF; i++) if ($i == "packets") { print $(i + 1); exit } }
    '
}

input_before=$(counter_packets labcap29_input_seen)
forward_before=$(counter_packets labcap29_forward_web)

printf 'STEP 3 DNAT and hook counters\n'
ready_file="$work_dir/service-ready"
ip netns exec labcap29server python3 "$start_dir/http_service.py" 8080 "$ready_file" \
    > "$work_dir/service.log" &
service_pid=$!
for _ in {1..50}; do
    [[ -s "$ready_file" ]] && break
    sleep 0.02
done
[[ -s "$ready_file" ]]
ip netns exec labcap29client python3 "$start_dir/http_probe.py" allow 10.29.1.1 18080
wait "$service_pid"
service_pid=
cat "$work_dir/service.log"

input_after=$(counter_packets labcap29_input_seen)
forward_after=$(counter_packets labcap29_forward_web)
printf 'INPUT_COUNTER=%s->%s\n' "$input_before" "$input_after"
printf 'FORWARD_WEB_COUNTER=%s->%s\n' "$forward_before" "$forward_after"
if (( input_after != input_before || forward_after <= forward_before )); then
    printf 'ERROR packet counters do not identify the forward path\n' >&2
    exit 1
fi

printf 'CONNTRACK_TRANSLATION\n'
ip netns exec labcap29 conntrack -L -p tcp | grep -E 'dst=10[.]29[.](1[.]1|2[.]2)' || true

printf 'STEP 4 default drop\n'
ip netns exec labcap29client python3 "$start_dir/http_probe.py" block 10.29.2.2 9090
