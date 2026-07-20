# Chapter 5 - The chain and the custodian - answers

## The completed TODOs

TODO 1 (5.2) - the CLI is just an API client. Ask the daemon its version over the
raw UNIX socket, proving the socket is the real interface:

    ver=$(curl -s --unix-socket "$SOCK" http://localhost/version \
            | grep -o '"Version":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "api_version=$ver" > "$OUT/chain.txt"

TODO 2 (5.5) - the container's parent process, read from /proc/<ppid>/comm. It is
a containerd-shim, the custodian - not dockerd:

    echo "parent_comm=$(cat "/proc/$ppid/comm")" >> "$OUT/chain.txt"

TODO 3 (5.4) - the grandparent, one step higher. Read the parent's own parent from
/proc/<ppid>/stat (field 4), then its comm. It is systemd (or containerd), never
dockerd:

    gppid=$(awk '{print $4}' "/proc/$ppid/stat")
    echo "grandparent_comm=$(cat "/proc/$gppid/comm")" >> "$OUT/chain.txt"

## Reflection answers

a. docker is only a client: it turns your command into an HTTP request and sends
it to dockerd over the socket. We proved it by calling /version and
/containers/json with curl and getting the same answers the CLI would print. This
is why the error is "Cannot connect to the Docker daemon", not "docker is broken":
the client is fine, the daemon (the kitchen) is down. It is also why writing to
that socket equals root on the host (chapter 23): whoever can talk to it can ask
the root daemon for anything.

b. If runc creates the container and then exits, something else must keep the
container alive - and it is the shim. The proof is in the process tree: the
container's parent is a containerd-shim, and above the shim is systemd (or
containerd), not dockerd. Because the container is a child of the shim and not of
the daemon, you can stop or upgrade dockerd and the container keeps running,
custodied by its shim; when the daemon returns it finds it again. That is
live-restore, and it is a direct consequence of the shim's place in the tree.

c. To watch live-restore for real you enable it and restart the daemon:

    echo '{ "live-restore": true }' | sudo tee /etc/docker/daemon.json
    sudo systemctl restart docker

  The container's host PID is unchanged across the restart. This lab does not
automate that step on purpose: restarting the shared daemon would disturb every
other container on the host (a real risk on a machine running other workloads).
On your own development host it is safe to try; in a shared or CI environment,
run it inside an isolated docker-in-docker sandbox so the restart cannot affect
anything else.
