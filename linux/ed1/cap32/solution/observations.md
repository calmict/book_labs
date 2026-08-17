# Osservazioni / Observations

Il container vede la propria shell come PID 1 e una vista proc costruita dopo il cambio di radice. Il processo sentinella resta nel namespace PID antenato e non compare: il test atteso è quindi host_process_visible=no. Dopo lo smontaggio di /.oldroot, il filesystem precedente non è più raggiungibile dal container.

The container sees its own shell as PID 1 through a proc view mounted after the root switch. The sentinel remains in the ancestor PID namespace and does not appear, so the expected result is host_process_visible=no. Once /.oldroot is unmounted, the previous filesystem is no longer reachable from the container.

La veth termina in un namespace esterno che funge da lato host del laboratorio. Anche questo namespace è rootless e separato dalla rete reale: il container può raggiungere 10.200.32.1, ma il laboratorio non aggiunge interfacce o rotte all'host reale.

The veth terminates in an outer namespace that serves as the lab's host side. That namespace is also rootless and separate from the real network: the container can reach 10.200.32.1, but the lab adds no interfaces or routes to the real host.

Il carico CPU consuma la quota di mezzo core e incrementa nr_throttled. La scrittura su tmpfs supera i 96 MiB concessi al cgroup; memory.oom.group termina il gruppo container, mentre il processo di controllo resta nel cgroup manager e può leggere oom_kill e completare la pulizia.

The CPU workload consumes the half-CPU quota and increments nr_throttled. Writing to tmpfs crosses the cgroup's 96 MiB allowance; memory.oom.group kills the container group while the controller remains in the manager cgroup, where it can read oom_kill and complete cleanup.
