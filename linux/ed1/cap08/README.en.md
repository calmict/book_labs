# Chapter 8 — Write a Service and Measure a Boot

> Exercise for **Chapter 8 — PID 1: From init to systemd** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- write and validate a user unit with explicit dependencies;
- configure and observe an automatic restart;
- distinguish an immediate start with systemctl --user start from enablement at future starts with systemctl --user enable;
- compare systemd-analyze blame with systemd-analyze critical-chain without confusing duration with impact on the critical path.

## Prerequisites

- A Linux host booted with systemd.
- A user session with the systemd bus available; check it with:

      systemctl --user is-system-running

- The bash, systemctl, systemd-analyze, install, awk, and sed commands.
- No administrative privileges. The units are installed below ~/.config/systemd/user and transient data is kept in the user's runtime directory.

## Instructions

1. Read solution/labcap08-ready.service and solution/labcap08-timestamp.service. The first unit creates a marker and is a oneshot dependency; the second refers to it with Wants and After.

2. Copy both units to ~/.config/systemd/user, then reload the user manager:

      mkdir -p ~/.config/systemd/user
      install -m 0644 solution/labcap08-ready.service ~/.config/systemd/user/
      install -m 0644 solution/labcap08-timestamp.service ~/.config/systemd/user/
      systemctl --user daemon-reload

3. Start the service without enabling it and compare the two states:

      systemctl --user start labcap08-timestamp.service
      systemctl --user is-active labcap08-timestamp.service
      systemctl --user is-enabled labcap08-timestamp.service

   The service intentionally fails only on its first execution. Restart=on-failure starts it again; two timestamps in the file displayed by solution/run.sh prove that both executions occurred.

4. Stop the service, enable it, and verify that enable alone does not start it:

      systemctl --user stop labcap08-timestamp.service labcap08-ready.service
      systemctl --user enable labcap08-timestamp.service
      systemctl --user is-enabled labcap08-timestamp.service
      systemctl --user is-active labcap08-timestamp.service

   Enable creates the link used for a future user-manager start; start changes the current session state. Start it explicitly to complete the test.

5. Run the complete solution. The script installs the units, performs both tests, displays the log and restart counter, and removes everything even if an error occurs:

      solution/run.sh

6. Analyze the host boot without changing it:

      systemd-analyze blame --no-pager
      systemd-analyze critical-chain --no-pager

   Record the first unit from blame and the critical path in start/observations.md. A slow unit may have run in parallel without delaying the target; blame measures time spent activating, whereas critical-chain reconstructs the timing dependencies leading to the selected target. Critical-chain can also omit waits that are not expressed as dependencies and is not, by itself, a causal diagnosis.

7. If you ran the commands manually, remove the user units:

      systemctl --user disable --now labcap08-timestamp.service
      systemctl --user stop labcap08-ready.service
      rm -f ~/.config/systemd/user/labcap08-timestamp.service
      rm -f ~/.config/systemd/user/labcap08-ready.service
      systemctl --user daemon-reload
      systemctl --user reset-failed

## Definition of "done"

- [ ] The main service starts only after its oneshot dependency.
- [ ] The log contains at least two timestamps and NRestarts is at least 1.
- [ ] After start, the service is active but not enabled.
- [ ] After enable and before the new start, the service is enabled but inactive.
- [ ] You compared the first blame entry with the critical chain and explained why they need not identify the same unit.
- [ ] The lab units, enablement link, and runtime data no longer exist at the end.

## Safety

The lab uses systemctl --user exclusively. Do not copy these units to /etc/systemd/system and do not prefix the commands with sudo. The script stops if it finds existing units with the same names, so it cannot overwrite prior work.
