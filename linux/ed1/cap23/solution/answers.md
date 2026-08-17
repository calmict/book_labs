# Expected observations

## Enforcing denial

The server runs as httpd_t. A world-readable file with a type such as user_home_t is still denied because discretionary mode bits and SELinux policy are independent checks. The demonstration handler turns the failed open operation into HTTP 403.

## Label repair

Changing only the type to httpd_sys_content_t permits the httpd_t process to read the file, so the next request returns 200. The numeric Unix mode before and after chcon is identical.

## Domain-limited permissive mode

When httpd_t alone is listed as permissive, the denied operation is allowed but an AVC is still produced for diagnosis. Removing the permissive declaration restores enforcement for that domain. Disabling SELinux globally is unnecessary and unsafe on a shared host.

## Visible arguments

/proc/PID/cmdline exposes the process argument vector. On a normal Linux configuration, another local user can read it, so a command-line secret can leak through process inspection and monitoring. Prefer a protected file descriptor, a mode-600 file, a dedicated secret store, or a program's standard-input mechanism when supported.

## Cleanup

The scripts use EXIT traps to stop their HTTP process, remove the container, undo the type-specific permissive declaration, restore the scratch context, and delete scratch data.
