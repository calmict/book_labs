# Observations

## Interrupt distribution

The first columns in /proc/interrupts are cumulative counters per logical CPU. A network queue may be pinned to one CPU or spread across several CPUs through multiple queues and interrupt affinity. Virtualized environments may expose no identifiable network row, which is itself an observation to record.

## Socket pressure

A small SO_RCVBUF combined with a receiver that temporarily stops reading makes Udp RcvbufErrors and the socket drop field grow. Loopback RX dropped need not change: the interface delivered the datagrams to the protocol stack, but the destination socket could not queue them.

## Conntrack pressure

The nft rule turns loopback UDP traffic into tracked connections, but nf_conntrack_max itself is not namespace-isolated on this kernel: writing 128 from inside labcap27 is accepted without error, yet the value read back from inside labcap27 and from the initial namespace stays unchanged. All 512 distinct flows get tracked and every source reaches the receiver — the opposite of what a real per-namespace ceiling would produce. Unlike net.ipv4.ip_forward in chapter 26, which genuinely differs per namespace, nf_conntrack_max is a single kernel-wide variable that merely appears under every namespace's /proc/sys tree. Deleting labcap27 removes the entries and the temporary nft table; the host's real nf_conntrack_max was never touched.
