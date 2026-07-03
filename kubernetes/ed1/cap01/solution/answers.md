# Chapter 1 — Answers (model solution)

## PID as seen from the host

        PID    PPID CMD
    1346733 1346711 sleep infinity

## PID as seen from inside the container

    PID   USER     TIME  COMMAND
        1 root      0:00 sleep infinity
        7 root      0:00 ps aux

## Hostname: host vs container

    host:      myworkstation
    container: d2f8d3f7324f

(the exact values — host PID, host hostname, container ID — change on every
run: what matters is the relationship between the two views, not the numbers
themselves)

## Why does the same process have two different PIDs?

They are not two processes: it is the exact same Linux process, seen through
two different windows onto the same process table of the host kernel. A
container does not virtualize a separate computer with its own kernel: it
takes a real process of the host kernel and, through the PID namespace, shows
it a private view in which that process believes it is the only one (PID 1).
From outside the namespace (the host) the same process has the real PID
assigned by the kernel. This is the difference between "isolating what a
process can see" and "duplicating the hardware": a VM would have a truly
separate kernel and process table, a container does not.
