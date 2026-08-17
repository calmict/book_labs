# Observations

## Interrupt distribution

- Network-related row:
- Per-CPU counters:
- Interpretation:

## Socket pressure

- Udp RcvbufErrors before and after:
- Socket drops reported by ss:
- Loopback RX dropped before and after:
- Why these counters describe different layers:

## Conntrack pressure

- nf_conntrack_max written inside labcap27, then read back inside labcap27 and from the initial namespace:
- Unique flows sent and unique sources received:
- Did the declared limit change anything? Evidence:
- Why nf_conntrack_max behaves differently from net.ipv4.ip_forward (chapter 26):
