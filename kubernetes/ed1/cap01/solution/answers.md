# Chapter 1 - A container is just a process - answers

## The completed TODOs

TODO 1 (1.2) obtains the host PID:

    HOST_PID=$(docker inspect --format '{{.State.Pid}}' "$CONTAINER")

TODO 2 (1.2) writes the host PID, hostname and process count to host.txt.

TODO 3 (1.3) runs the equivalent observations with docker exec and writes them to inside.txt.

The complete implementation is solution/observe.sh.

## Reflection answers

a. A PID is a name inside a PID namespace. The host and container use different names for the same kernel process.

b. The UTS and PID namespaces restrict the hostname and process-table views. They do not boot or duplicate a kernel.

c. Host PID mode removes the private process-numbering view. The process keeps its host-style PID, proving that PID 1 came from isolation rather than from a separate machine.
