# Setup — Docker exercises

## Recommended environment

Native Linux with Docker Engine. On native Linux the kernel mechanisms the book
explains (namespaces, cgroups, overlay, iptables) are the real ones, observable
with lsns, nsenter and the files under /sys/fs/cgroup. Docker Desktop and WSL2
work for most labs but run Docker inside a Linux VM, which hides some of what the
early chapters want to show (see Appendix A of the book).

## Install Docker Engine (native Linux)

    curl -fsSL https://get.docker.com | sudo sh
    docker version
    docker run --rm hello-world

To use Docker without sudo you must join the docker group - but read chapter 23
first: membership in the docker group is equivalent to root on the host.

    sudo usermod -aG docker "$USER"   # then log out and back in

## The kernel-foundations labs (Part 1)

Chapters 1 to 4 need no Docker and no root: they build containers by hand with
unshare and inspect them with lsns and /proc. They require:

- util-linux (unshare, lsns, nsenter) - present on any modern Linux
- cgroup v2 (the default today): check with

    stat -fc %T /sys/fs/cgroup   # cgroup2fs = v2

## Running an exercise

    cd docker/ed1/capNN
    # complete the TODOs in start/ following README.it.md or README.en.md
    cd solution
    ./run.sh                      # prints OK 1.. and ALL CHECKS PASSED
