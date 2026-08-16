# Chapter 12 — Model Observations

## Reload with SIGHUP

The service logs the new configuration value after SIGHUP while ps and the log show the original PID. The signal handler only sets a flag; the main execution path performs the file operations safely.

## SIGTERM and SIGKILL

After SIGTERM, the service logs an orderly shutdown and removes its work marker. After SIGKILL, wait reports status 137 and the marker remains. SIGKILL is handled by the kernel and cannot be caught, blocked, or ignored, so the process gets no opportunity to run cleanup code.

## Container shutdown

The faulty PID 1 ignores SIGTERM, so docker stop waits about ten seconds before sending SIGKILL. The corrected PID 1 catches SIGTERM, forwards it to its child, waits for that child, and exits. Its container therefore stops in well under the ten-second grace period.
