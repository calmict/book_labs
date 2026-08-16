# Chapter 10 — Model Observations

## Parent and child

The parent and child are visible at the same time. The child's PPID equals the parent's PID. Both continue after fork(), but the return value lets them select different branches: zero in the child and the child's PID in the parent. The parent eventually calls waitpid(), so the child does not remain a zombie.

## PID across exec

The PID recorded by process_lab is the same PID later shown by ps for sleep. exec() replaces the process image, including its code and data, but it does not create a new process. The process identity and PID therefore remain unchanged.

## Zombie lifecycle

Before the parent waits, ps reports the terminated child with state Z. The child has already finished and cannot execute a signal handler. SIGUSR1 is sent to the living parent, whose handler causes it to call waitpid(). That call collects the saved exit status, after which the child's PID disappears from the process table.
