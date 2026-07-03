# Chapter 3 — Answers (model solution)

## CPU: free vs caged

    free:  ~99% of one core
    caged: ~20% of one core (cpu.max = 20000 100000)

## cpu.stat after a while in the cage

    nr_throttled 50
    throttled_usec 3976096

## Memory: the evidence of the murder

    --- memory.events ---
    low 0
    high 0
    max 70
    oom 2
    oom_kill 1
    oom_group_kill 0
    --- memory.peak (bytes) ---
    67108864

(the exact counters change between runs; what matters is oom_kill at 1 and
memory.peak stopped at 67108864 bytes — exactly the 64M ceiling: the glutton
never got a byte more)

## The three questions

**1. Why does the CPU limit slow down without killing, while the memory limit
kills? (hint: compressible vs incompressible resource)**

CPU is a compressible resource: if the kernel gives a process fewer cycles,
the process simply runs slower — nothing breaks, work is only postponed. So
the scheduler can enforce cpu.max by pausing the process (throttling) at the
end of each period and letting it resume in the next one. Memory is
incompressible: a page that a process has written cannot be taken back
without destroying its state. When the cgroup is at memory.max and cannot
reclaim anything (no swap allowed), the only way to enforce the limit is to
kill a process inside the cgroup. Same accountant, two different verdicts,
dictated by the physics of the resource.

**2. What do cpu.max and memory.max correspond to in the Kubernetes world,
and where does a Pod's OOMKilled status come from?**

They are the raw mechanism behind a container's limits: the kubelet (through
the container runtime) translates resources.limits.cpu into cpu.max and
resources.limits.memory into memory.max of the container's cgroup. Requests,
instead, feed the scheduler and the cpu.weight / QoS placement. A Pod shown
as OOMKilled is exactly what we produced by hand in step 4: a process in the
container's cgroup hit memory.max, the kernel's OOM killer sent it a SIGKILL
(exit code 137), and the kubelet reported the reason.

**3. What do nr_throttled and oom_kill tell whoever is troubleshooting?**

They are the accountant's ledger. A growing nr_throttled (with a big
throttled_usec) on a slow application means the CPU limit is the bottleneck:
the app is alive but constantly punished — the fix is raising the limit, not
looking for a crash. An oom_kill greater than zero explains restarts that
look mysterious from the outside: the kernel, not the application, ended the
process. In Kubernetes these same counters are what metrics systems read from
the node to alert on CPU throttling and OOM kills per container.
