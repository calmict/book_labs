# Observations

## Hidden failure

The failed system call is openat. It returns -1 with ENOENT, which means that the requested configuration file does not exist. The program discards the exception, but the kernel-facing trace retains the actual reason.

## Pipe buffering

The buffered run exposes zero bytes while the process is sleeping. With Python's -u option, the first line is already visible. When stdout points to a pipe, stdio uses block buffering instead of the line-oriented behavior normally seen on a terminal. Using -u, flush=True, or an explicit flush makes progress visible immediately.

## Kernel setting

The values 0 and 1 are written and read back inside labcap26. The write affects the running kernel namespace immediately. A sysctl drop-in is configuration input that the system reloads during boot; the included example is intentionally not installed by the solution.
