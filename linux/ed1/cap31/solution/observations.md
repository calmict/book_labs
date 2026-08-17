# Osservazioni / Observations

Con cpu.max impostato a 50000 100000, il gruppo può usare 50 millisecondi di CPU ogni periodo di 100 millisecondi: equivale a mezzo core. Un carico sempre eseguibile consuma la quota, viene sospeso fino al periodo successivo e fa aumentare nr_throttled e throttled_usec.

With cpu.max set to 50000 100000, the group can use 50 milliseconds of CPU in each 100-millisecond period, which equals half a CPU. A continuously runnable workload exhausts that quota, pauses until the next period, and increases nr_throttled and throttled_usec.

Il carico da 72 MiB supera memory.high a 32 MiB, quindi subisce reclaim diretto e rallentamento ma può terminare perché memory.max resta a 96 MiB. Lo stesso carico supera invece memory.max a 48 MiB e viene terminato dall'OOM del gruppo. memory.oom.group limita la conseguenza ai processi del cgroup.

The 72 MiB workload crosses a 32 MiB memory.high value, so it experiences direct reclaim and throttling but can finish because memory.max remains at 96 MiB. The same workload crosses a 48 MiB memory.max value and is killed by the group's OOM handler. memory.oom.group confines the consequence to processes in that cgroup.
