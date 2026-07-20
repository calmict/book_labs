# Chapter 2 - The six rooms - answers

## The completed TODOs

TODO 3 (2.1) - the host namespace inodes, recorded before building the isolated
process, as the yardstick for the comparison:

    {
      echo "host_uts=$(readlink /proc/self/ns/uts)"
      echo "host_pid=$(readlink /proc/self/ns/pid)"
      echo "host_mnt=$(readlink /proc/self/ns/mnt)"
      echo "host_net=$(readlink /proc/self/ns/net)"
    } > "$OUT/host.txt"

TODO 1 (2.2-2.5) - the flags that open one room each. Without them unshare opens
only a USER namespace; the isolation comes from adding the rest:

    unshare --user --map-root-user --uts --pid --fork --mount-proc --mount --net \
      bash -c '...' bash "$OUT"

  --uts isolates the hostname; --pid --fork give a new PID numbering with the
  shell as PID 1; --mount-proc remounts /proc; --mount gives a private mount
  table; --net gives a private, near-mute network stack (only loopback).

TODO 2 (2.4) - the proof of the MNT namespace, done inside the child: mount a
private tmpfs and drop a marker in it. The host never sees this mount.

    mount -t tmpfs tmpfs /mnt && echo mounted > /mnt/marker

## Reflection answers

a. Each namespace attacks a different view. UTS isolates the hostname; PID the
process numbering (so we are PID 1); MNT the mount table (so a mount here is
invisible outside); NET the whole network stack (so the process is nearly mute
until you give it a veth, chapter 16); USER the uid/gid mapping (so we are root
inside while a plain user outside). None of them creates a second machine: each
just changes one thing the process is allowed to see. The metric that proves it
is the inode in /proc/<pid>/ns: a different inode means a separate world for that
one resource, while everything else - the kernel above all - is shared.

b. We are root inside (uid 0) yet used no sudo because of the USER namespace: the
kernel maps uid 0 in our new world to our unprivileged uid on the host. Inside we
may create the other namespaces (which is why the rootless build works at all);
outside we hold no real power. This is exactly the mechanism that makes rootless
Docker possible (chapter 23) and the same one behind the "files owned by root" on
shared volumes (chapter 15) - one idea, two later payoffs.

c. Dropping --net removes only the network room: the process now shares the
host's net namespace (its net inode matches the host's), while it still has its
own PID, UTS and MNT rooms. This is the whole point: a container's isolation is
not one switch but the sum of the individual namespaces you choose to open. Open
five and leave one shared, and you get exactly five isolations and one shared
resource - which is precisely what --network host does on purpose (chapter 18).
