# Expected observations

## Pipe capacity

F_GETPIPE_SZ reports the current kernel capacity for that pipe. Nonblocking writes reach the same byte count before EAGAIN. The value is a property to measure: kernel settings, limits, and pipe history can make it differ across systems.

## Backpressure

Once the pipe is full, a blocking write sleeps until the consumer frees enough buffer space. The demonstration delays the consumer for 0.30 seconds, confirms that the producer has not completed, then reads one memory page. The pending write finishes shortly afterward.

## The while loop

The pipeline prints count=0 because Bash ran the loop in a child subshell and discarded its private variable update at exit. Process substitution feeds the loop through redirection while the loop remains in the current shell, so it prints count=3.

## Status 141

head succeeds with status 0 after consuming one line. It then closes the pipe, and the producer receives signal 13 while attempting another write. Shells encode a signal termination as 128 plus the signal number, hence 141. pipefail exposes that producer failure as the pipeline status.

## Cleanup

The Python program closes its pipe ends and joins its bounded producer thread. The shell pipeline processes are reaped before the scripts exit.
