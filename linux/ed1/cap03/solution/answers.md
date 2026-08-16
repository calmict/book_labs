# Chapter 3 — Answers (model solution)

## System call summary

The exact counts depend on the C library, executable, and distribution. The total
line in the strace -c table is the value to report; it is normally much greater
than one even though printf emits only one application-level line. Calls commonly
include mmap, openat, close, newfstatat, mprotect, and write.

## Missing file

The relevant record has this form:

    openat(AT_FDCWD, "/tmp/labcap03-file-that-does-not-exist", O_RDONLY) = -1 ENOENT (No such file or directory)

openat is the request. A return value of -1 reports failure, and ENOENT identifies
the reason: no directory entry exists for that path.

## UID 0 process

The shell prints UID 0. Its trace still contains openat and write requests because
it cannot directly open a file or send bytes to a file descriptor. It crosses the
system-call boundary and asks the kernel to perform those operations.

## UID versus CPU mode

UID 0 is a credential the kernel consults while making authorization decisions.
User mode and kernel mode are CPU execution states. A normal root process runs its
application instructions in user mode just like an unprivileged process; only the
kernel runs privileged instructions while serving its system calls. Greater
authorization does not turn application code into kernel code.
