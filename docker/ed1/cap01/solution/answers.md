# Chapter 1 - The bare-hands container - answers

## The completed TODOs

TODO 3 (1.5) - the host's point of view, written before building the container:

    {
      echo "host_hostname=$(hostname)"
      echo "host_pidns=$(readlink /proc/self/ns/pid)"
    } > "$OUT/host.txt"

TODO 1 (1.4) - the flags that create the isolation. Without them unshare only
opens a USER namespace; the isolation comes from these four:

    unshare --user --map-root-user --uts --pid --fork --mount-proc \
      bash -c '...' bash "$OUT"

  --uts gives an isolated hostname; --pid --fork give a new PID numbering with
  bash as PID 1; --mount-proc remounts /proc so it reflects the new PID
  namespace (otherwise ps would still show the host's processes).

TODO 2 (1.4) - the proof from inside, written by the child shell:

    hostname nave-cargo
    {
      echo "inside_hostname=$(hostname)"
      echo "inside_pid=$$"
      echo "inside_proc_count=$(ps -e --no-headers 2>/dev/null | wc -l)"
      echo "inside_pidns=$(readlink /proc/self/ns/pid)"
    } > "$1/inside.txt"

## Reflection answers

a. The container is a normal process because, from the host, it has an ordinary
PID and can be killed with a plain kill: nothing about it is a separate machine.
What makes it "feel" like a machine is only the set of restricted views the
kernel gives it - here a new PID namespace (so it renumbers processes from 1)
and a new UTS namespace (so its hostname is its own). Change the set of
namespaces and you change what the process can see; you never create a second
computer.

b. Inside, our shell is PID 1 because the PID namespace renumbers processes from
1 for the processes it contains, and --fork makes the shell the first one. On the
host that same shell has a large PID, visible with a normal ps. Both numbers name
the identical process: the inside view is filtered and renumbered, not separate.
This is exactly why the pid-namespace inode read inside matches the one the host
reads for that PID, while differing from the host's own namespace inode.

c. Dropping --pid removes the new PID numbering, so the shell is no longer PID 1
(it keeps a host-style PID) and ps inside would show the host's processes. The
isolation of the process list is precisely the --pid flag; remove it and that
particular mask is gone, even though the USER and (if kept) UTS masks remain.
Isolation is not all-or-nothing: it is the sum of the individual namespaces you
choose to create.
