# Verified observations

## Live process

The inspection process keeps an ordinary file descriptor open, allocates and touches memory, and remains alive until the runner sends SIGTERM. The fd directory exposes links to its open objects, status provides a concise process and memory summary, and smaps_rollup aggregates its mappings. Namespace entries are links whose targets contain a namespace type and inode.

## Zombie

The child exits immediately while the parent deliberately postpones waitpid. During that interval, ps and status report Z. SIGUSR1 tells the parent to call waitpid; after that call, the child PID is absent from /proc.

## FIFO wait

Opening a FIFO for reading when no writer exists sleeps interruptibly. The measured state is S, and SIGKILL terminates the process. This mechanism cannot create or verify state D. A claim that the FIFO process remained in D after SIGKILL would contradict the observed kernel state.
