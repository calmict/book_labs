# Observations

## Enforcing denial

Record the server process context, the incorrect file label, its Unix mode, and the first HTTP status code.

## Label repair

Record the corrected label, the unchanged Unix mode, and the new HTTP status code. Explain why chmod was irrelevant.

## Domain-limited permissive mode

Record the HTTP result with httpd_t permissive and one relevant AVC line. Confirm that the exception was removed.

## Visible arguments

Record what the second container user read from /proc/PID/cmdline. Explain the safer alternatives for delivering a secret.

## Cleanup

Confirm that the HTTP process, scratch directory, container, and permissive exception are gone.
