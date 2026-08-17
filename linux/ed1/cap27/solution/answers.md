# Observations

## Interrupt distribution

The first columns in /proc/interrupts are cumulative counters per logical CPU. A network queue may be pinned to one CPU or spread across several CPUs through multiple queues and interrupt affinity. Virtualized environments may expose no identifiable network row, which is itself an observation to record.

## Socket pressure

A small SO_RCVBUF combined with a receiver that temporarily stops reading makes Udp RcvbufErrors and the socket drop field grow. Loopback RX dropped need not change: the interface delivered the datagrams to the protocol stack, but the destination socket could not queue them.

## Conntrack pressure

The solution limits the isolated table to 128 entries and attempts 512 distinct UDP flows. The namespace's nf_conntrack_count approaches its ceiling, while insert_failed records flows that could not be inserted. The receiver sees fewer unique sources than the sender attempted. Deleting labcap27 removes both the entries and the temporary nft table.
