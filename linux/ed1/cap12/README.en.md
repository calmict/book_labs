# Chapter 12 — Talk to a Process That Refuses to Listen

> Exercise for **Chapter 12 — Signals: The Kernel's Messaging System** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- catch SIGTERM and perform an orderly shutdown outside the signal handler;
- prove that SIGKILL cannot be caught and prevents application cleanup;
- use SIGHUP to reload configuration without changing the PID;
- diagnose and fix a PID 1 process that makes docker stop wait for ten seconds.

## Prerequisites

- A Linux host with a C compiler, Bash, and the kill, ps, and timeout commands.
- A working Docker installation and permission to start containers for the final part.
- The alpine:3.20 image available locally, or access to download it.
- No administrative privileges are required.

## Instructions

1. Copy start/signal_service.c to a working directory. Complete the handlers; they must only set sig_atomic_t flags. The main loop will read configuration, write the log, and remove the work file.

2. Compile the service and start it with an initial configuration:

       cc -std=c11 -Wall -Wextra -Wpedantic -O2 signal_service.c -o signal_service
       printf 'mode=initial\n' > service.conf
       ./signal_service service.conf service.log work.marker ready.marker &
       service_pid=$!

3. Replace the configuration, send SIGHUP, and verify that the same PID records the new value:

       printf 'mode=reloaded\n' > service.conf
       kill -HUP "$service_pid"
       ps -p "$service_pid" -o pid,stat,comm
       cat service.log

4. Send SIGTERM and wait for the process. The log must contain the orderly-shutdown entry, and work.marker must have been removed:

       kill -TERM "$service_pid"
       wait "$service_pid"
       test ! -e work.marker

5. Start a new instance, send SIGKILL, and wait for it. This time work.marker must remain: the kernel terminates the process without running cleanup code.

       kill -KILL "$service_pid"
       wait "$service_pid"
       test -e work.marker

   Remove the leftover file manually after recording the observation.

6. Before the container test, inspect the list returned by docker ps and make sure every following command targets only labcap12-slow or labcap12-fixed.

7. Reproduce a PID 1 that ignores SIGTERM. The internal process has a finite duration, the container has explicit limits, and docker stop has an outer timeout:

       docker run -d --rm --name labcap12-slow --cpus=0.25 --memory=64m \
         --pids-limit=32 --network none alpine:3.20 \
         sh -c 'trap "" TERM; sleep 60 & wait'
       time timeout --signal=TERM --kill-after=2s 15s docker stop --time 10 labcap12-slow

   docker stop must wait for about ten seconds before falling back to SIGKILL.

8. Complete start/container_entrypoint.sh so PID 1 catches SIGTERM, terminates and reaps its child, then exits. Start the corrected version by mounting the script read-only:

       docker run -d --rm --name labcap12-fixed --cpus=0.25 --memory=64m \
         --pids-limit=32 --network none \
         -v "$PWD/container_entrypoint.sh:/lab/container_entrypoint.sh:ro" \
         alpine:3.20 sh /lab/container_entrypoint.sh
       time timeout --signal=TERM --kill-after=2s 15s docker stop --time 10 labcap12-fixed

   Shutdown must take much less than ten seconds. The solution runs and checks every step:

       ./solution/run.sh

## Definition of "done"

- [ ] SIGHUP reloads the changed value and the service PID does not change.
- [ ] SIGTERM produces an orderly-shutdown entry and removes the work file.
- [ ] SIGKILL leaves the work file behind, proving that cleanup did not run.
- [ ] The faulty container takes about ten seconds to stop.
- [ ] The corrected PID 1 forwards termination to its child, reaps it, and stops quickly.
- [ ] No test process or labcap12 container remains active.
