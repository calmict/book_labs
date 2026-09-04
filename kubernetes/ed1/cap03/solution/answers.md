# Chapter 3 - Limiting CPU and RAM by hand - answers

## The completed TODOs

TODO 1 (3.1, 3.2) reads and checks the controllers of the newly created cgroup:

    controllers=$(cat "$LAB_CG/cgroup.controllers")
    grep -qw memory <<< "$controllers"
    grep -qw pids <<< "$controllers"

TODO 2 (3.3) applies the hard memory and swap ceilings to a systemd user scope:

    systemd-run --user --scope -q --collect \
      -p MemoryMax=20M -p MemorySwapMax=0 \
      python3 -c "b=bytearray(200*1024*1024); print('ALLOCATED')"

TODO 3 (3.3) applies the process ceiling to another user scope:

    systemd-run --user --scope -q --collect -p TasksMax=3 \
      bash -c 'for i in 1 2 3 4 5 6; do sleep 1 & done; wait'

## Reflection answers

a. CPU is compressible: delaying cycles only slows work. Used memory holds process state, so enforcing a hard unreclaimable limit may require killing a process.

b. The kubelet and runtime translate container CPU and memory limits into cgroup controller settings. OOMKilled reports the kernel killing a container process after the memory ceiling is reached.

c. Growing nr_throttled identifies CPU quota pressure. A growing oom_kill counter explains a forced memory-related termination. TasksMax and pids.max reject new processes before they can exhaust the host PID space.
