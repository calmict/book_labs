# Chapter 23 — Stop Root with a Policy

> Exercise for **Chapter 23 — Mandatory Access Control and Hardening** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Advanced

## Objectives

By the end of this lab you will be able to:

- identify an SELinux denial that appears as an HTTP 403 response;
- fix a content label without broadening Unix permissions;
- use permissive mode for one domain only while diagnosing a denial;
- prove that process arguments are not a safe place for secrets.

## Prerequisites

- Rocky Linux with SELinux in Enforcing mode.
- Administrative privileges for chcon, runcon, and semanage.
- Python 3, curl, and the policycoreutils and policycoreutils-python-utils packages.
- Docker or Podman for the isolated two-user test.

Do not use setenforce. Do not change persistent configuration, system services, or Unix permissions while fixing the 403.

## Instructions

1. Copy the answer template and record the initial state and context:

       cp start/answers.md answers.md
       getenforce
       id -Z
       ls -Zd .

2. Review solution/selinux-lab.sh. The script creates an ephemeral HTTP server on an unprivileged port, assigns httpd_t only to the lab process with runcon, and prepares a file whose label that domain cannot read. It does not start or restart any real service.

3. Run the SELinux test with administrative privileges:

       sudo ./solution/selinux-lab.sh

   Record the 403 response, process context, and file label. Confirm that the file's mode bits do not change when chcon assigns httpd_sys_content_t and the request changes to 200.

4. Watch the diagnostic phase of the same script. The file is given the wrong label again, but semanage permissive -a httpd_t makes only that type permissive. The request succeeds while the AVC remains available for diagnosis. The script immediately removes the exception with semanage permissive -d httpd_t. Never replace these commands with a global toggle.

5. Run the second test:

       ./solution/proc-arguments-lab.sh

   Inside an ephemeral container, one user starts a process with labcap23-demo-secret among its arguments. Another user reads /proc/PID/cmdline and prints the same value. Explain why passwords, tokens, and keys must not be passed on a command line.

6. You can run both checks with:

       sudo ./solution/run.sh

   The script explicitly reports an incompatible environment instead of claiming that a skipped test passed.

## Definition of "done"

- [ ] You reproduced a label-driven 403 and a 200 after chcon, without chmod.
- [ ] You diagnosed the denial by making only httpd_t permissive, then removed the exception.
- [ ] A second user in the container read the secret from /proc/PID/cmdline.
- [ ] No lab server or container remains active, and the scratch directory was removed.
- [ ] answers.md contains the requested contexts, HTTP status codes, and explanations.
