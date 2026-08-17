#!/usr/bin/env bash
set -Eeuo pipefail

namespace=labcap27
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
start_dir=$(cd -- "$script_dir/../start" && pwd)
work_dir=$(mktemp -d -t labcap27.XXXXXX)
namespace_created=0
receiver_pid=
server_pid=
client_pid=

cleanup() {
    local status=$?
    trap - EXIT INT TERM
    for process_id in "$receiver_pid" "$server_pid" "$client_pid"; do
        if [[ -n "$process_id" ]]; then
            kill "$process_id" 2>/dev/null || true
            wait "$process_id" 2>/dev/null || true
        fi
    done
    if (( namespace_created )); then
        ip netns del "$namespace" >/dev/null 2>&1 || true
    fi
    rm -rf -- "$work_dir"
    printf 'CLEANUP namespace=%s processes=stopped temporary_files=removed\n' "$namespace"
    exit "$status"
}
trap cleanup EXIT INT TERM

for command_name in ip python3 awk grep ss nft conntrack sysctl; do
    command -v "$command_name" >/dev/null || {
        printf 'ERROR missing command: %s\n' "$command_name" >&2
        exit 1
    }
done

printf 'STEP 1 network interrupts by CPU\n'
interrupt_header=$(head -n 1 /proc/interrupts || true)
interrupt_rows=$(grep -Ei 'eth|enp|eno|ens|virtio|mlx|ixgbe|network' /proc/interrupts || true)
printf 'INTERRUPT_HEADER=%s\n' "$interrupt_header"
if [[ -n "$interrupt_rows" ]]; then
    printf '%s\n' "$interrupt_rows"
else
    printf 'INTERRUPT_NETWORK_ROWS=none_exposed\n'
fi

if (( EUID != 0 )); then
    printf 'SKIP isolated network checks require root; rerun this script with sudo\n'
    exit 0
fi
if ip netns list | awk '{print $1}' | grep -Fxq "$namespace"; then
    printf 'ERROR namespace %s already exists\n' "$namespace" >&2
    exit 1
fi
ip netns add "$namespace"
namespace_created=1
ip -n "$namespace" link set lo up

udp_rcvbuf_errors() {
    ip netns exec "$namespace" awk '
        $1 == "Udp:" && $2 == "InDatagrams" {
            for (i = 2; i <= NF; i++) name[i] = $i
            getline
            for (i = 2; i <= NF; i++) if (name[i] == "RcvbufErrors") print $i
        }
    ' /proc/net/snmp
}

loopback_rx_dropped() {
    ip -n "$namespace" -s link show lo | awk '
        $1 == "RX:" { getline; print $4; exit }
    '
}

printf 'STEP 2 socket receive-buffer loss\n'
rcvbuf_before=$(udp_rcvbuf_errors)
link_drop_before=$(loopback_rx_dropped)
ip netns exec "$namespace" python3 "$start_dir/socket_pressure.py" receive 27270 \
    > "$work_dir/socket-receiver.log" &
receiver_pid=$!
for _ in {1..50}; do
    grep -q '^READY' "$work_dir/socket-receiver.log" && break
    sleep 0.02
done
grep -q '^READY' "$work_dir/socket-receiver.log"
ip netns exec "$namespace" python3 "$start_dir/socket_pressure.py" send 27270 50000
socket_snapshot=$(ip netns exec "$namespace" ss -u -a -n -m)
printf '%s\n' "$socket_snapshot" | grep '127.0.0.1:27270' || true
wait "$receiver_pid"
receiver_pid=
cat "$work_dir/socket-receiver.log"
rcvbuf_after=$(udp_rcvbuf_errors)
link_drop_after=$(loopback_rx_dropped)
printf 'UDP_RCVBUF_ERRORS=%s->%s\n' "$rcvbuf_before" "$rcvbuf_after"
printf 'LO_RX_DROPPED=%s->%s\n' "$link_drop_before" "$link_drop_after"
if (( rcvbuf_after <= rcvbuf_before )); then
    printf 'ERROR socket receive-buffer errors did not increase\n' >&2
    exit 1
fi

printf 'STEP 3 nf_conntrack_max and the namespace illusion\n'
ip netns exec "$namespace" nft add table inet labcap27
ip netns exec "$namespace" nft \
    'add chain inet labcap27 output { type filter hook output priority filter; policy accept; }'
ip netns exec "$namespace" nft add rule inet labcap27 output ct state new accept

host_max_before=$(cat /proc/sys/net/netfilter/nf_conntrack_max)
ip netns exec "$namespace" sysctl -w net.netfilter.nf_conntrack_max=128
netns_max_after=$(ip netns exec "$namespace" cat /proc/sys/net/netfilter/nf_conntrack_max)
host_max_after=$(cat /proc/sys/net/netfilter/nf_conntrack_max)
printf 'HOST nf_conntrack_max before the namespace write: %s\n' "$host_max_before"
printf 'NETNS nf_conntrack_max read back inside labcap27: %s\n' "$netns_max_after"
printf 'HOST nf_conntrack_max read back from the initial namespace: %s\n' "$host_max_after"
if (( netns_max_after != host_max_before )) || (( host_max_after != host_max_before )); then
    printf 'ERROR nf_conntrack_max changed on this kernel; the namespace-illusion premise no longer holds here\n' >&2
    exit 1
fi

count_before=$(ip netns exec "$namespace" conntrack -C)
ready_file="$work_dir/conntrack-ready"
ip netns exec "$namespace" python3 "$start_dir/conntrack_pressure.py" \
    server 27271 "$ready_file" > "$work_dir/conntrack-server.log" &
server_pid=$!
for _ in {1..50}; do
    [[ -s "$ready_file" ]] && break
    sleep 0.02
done
[[ -s "$ready_file" ]]
ip netns exec "$namespace" python3 "$start_dir/conntrack_pressure.py" \
    clients 27271 512 > "$work_dir/conntrack-clients.log" &
client_pid=$!
wait "$client_pid"
client_pid=
count_after=$(ip netns exec "$namespace" conntrack -C)
wait "$server_pid"
server_pid=
cat "$work_dir/conntrack-clients.log"
cat "$work_dir/conntrack-server.log"
flows_sent=$(awk -F= '/^UNIQUE_FLOWS_SENT=/{print $2}' "$work_dir/conntrack-clients.log")
sources_received=$(awk -F= '/^UNIQUE_SOURCES_RECEIVED=/{print $2}' "$work_dir/conntrack-server.log")
printf 'CONNTRACK_COUNT=%s->%s (the 128 ceiling declared above was never actually applied)\n' "$count_before" "$count_after"
printf 'UNIQUE_FLOWS_SENT=%s UNIQUE_SOURCES_RECEIVED=%s\n' "$flows_sent" "$sources_received"
if (( sources_received != flows_sent )); then
    printf 'ERROR expected zero drops since the namespace write never took effect; sources_received differs from flows_sent\n' >&2
    exit 1
fi
