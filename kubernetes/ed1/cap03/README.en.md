# Chapter 3 — Limiting CPU and RAM by Hand

> Exercise for **Chapter 3 — Cgroups: The Resource Accountant** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- create a cgroup v2 by hand and read/write its control files, with no runtime involved;
- cage a running process and watch the two opposite fates: CPU gets slowed down (throttling), memory kills (OOM kill);
- connect cpu.max and memory.max to what Kubernetes calls requests/limits, and understand where the OOMKilled status comes from.

## Prerequisites

- Chapter 2 completed (namespaces: what a process sees; here: how much it consumes).
- A Linux host with cgroup v2 (any modern distro) and sudo privileges.

> ⚠️ **WSL2 note:** if step 1 does not report cgroup2fs, your WSL still mounts
> the hybrid v1 hierarchy: add the lines [wsl2] and
> kernelCommandLine = cgroup_no_v1=all to your %UserProfile%\\.wslconfig file,
> then run wsl --shutdown and try again.

> 💡 **No sudo?** systemd delegates only the memory and pids controllers to
> your user (check with: cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers).
> So you can do the memory part without root, like this:
>
>     systemd-run --user --scope -p MemoryMax=64M -p MemorySwapMax=0 -- sh -c 'sleep 30; head -c 200M /dev/zero | tail'
>
> During the 30-second pause, from a second terminal find the scope's cgroup
> (systemd-cgls --user) and read its memory.max and memory.current by hand;
> then watch the kill. The CPU part does require root: the cpu controller is
> not delegated. And do not try to move your shell's PID into the delegated
> cgroup by hand: the cgroup v2 "common ancestor" rule will stop you — that
> is exactly why systemd-run is the way in here.

## Instructions

1. Verify you are on cgroup v2 and look at which controllers exist:

       stat -fc %T /sys/fs/cgroup
       cat /sys/fs/cgroup/cgroup.controllers

   Expected: cgroup2fs, and a list that includes cpu and memory.

2. Create your cage and check which controllers it inherited:

       sudo mkdir /sys/fs/cgroup/lab-cap03
       cat /sys/fs/cgroup/lab-cap03/cgroup.controllers

3. **CPU slows down.** Start a process that devours a full core and measure it
   while free:

       sh -c 'while :; do :; done' &
       ps -o pid,%cpu,cmd -p $!

   Wait a few seconds and run the ps again: it should head towards 100%.
   Now impose 20% of one core and move the process into the cage (use the PID
   printed by $!):

       echo "20000 100000" | sudo tee /sys/fs/cgroup/lab-cap03/cpu.max
       echo <PID> | sudo tee /sys/fs/cgroup/lab-cap03/cgroup.procs

   Observe the consumption again after ten seconds or so — use
   top -b -n1 -p <PID> here, which is instantaneous, because ps shows the
   average since start — and read the punishment counter:

       grep -E 'nr_throttled|throttled_usec' /sys/fs/cgroup/lab-cap03/cpu.stat

   The process is not dead: it is just slower. Write down the values.

4. **Memory kills.** Impose a 64M ceiling (and no swap escape), then launch a
   glutton that would like 200M, already inside the cage:

       echo 64M | sudo tee /sys/fs/cgroup/lab-cap03/memory.max
       echo 0 | sudo tee /sys/fs/cgroup/lab-cap03/memory.swap.max
       sudo sh -c 'echo $$ > /sys/fs/cgroup/lab-cap03/cgroup.procs; head -c 200M /dev/zero | tail'

   Expected: "Killed" within a second. Collect the evidence of the murder:

       cat /sys/fs/cgroup/lab-cap03/memory.events
       cat /sys/fs/cgroup/lab-cap03/memory.peak
       sudo dmesg | tail -5

5. **(Bonus) The fork bouncer.** With pids.max at 5, a fork bomb becomes
   harmless:

       echo 5 | sudo tee /sys/fs/cgroup/lab-cap03/pids.max
       sudo sh -c 'echo $$ > /sys/fs/cgroup/lab-cap03/cgroup.procs; for i in 1 2 3 4 5 6 7 8; do sleep 30 & done'

   Count how many fork errors you get and check pids.events.

6. Answer in writing, in the answers.md file you will submit: why does the CPU
   limit slow down without killing, while the memory limit kills (compressible
   vs incompressible resource)? What do cpu.max and memory.max correspond to
   in the Kubernetes world, and where does a Pod's OOMKilled status come from?
   What do nr_throttled and oom_kill tell whoever is troubleshooting?

7. Tear down the lab: kill the loop from step 3 (kill <PID>), let the sleeps
   from step 5 finish, then:

       sudo rmdir /sys/fs/cgroup/lab-cap03

   (rmdir only works on an empty cage: if it complains, someone is still
   inside — find out who with cat /sys/fs/cgroup/lab-cap03/cgroup.procs.)

## Definition of "done"

- [ ] You saw the same loop first close to 100% of a core and then pinned at
      20%, with nr_throttled growing in cpu.stat.
- [ ] The glutton process was killed (Killed / exit 137) and memory.events
      records oom_kill 1, with memory.peak stopped just above 64M.
- [ ] Your answers.md file answers the three questions of step 6.
- [ ] The cage was removed with rmdir and no lab processes are left around.
