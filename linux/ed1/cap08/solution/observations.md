# Verified observations

## Service behavior

The main unit declares both an ordering relationship and a weak requirement on labcap08-ready.service. ExecStartPre succeeds only after the dependency has created ready-at.

The first main-process execution writes a timestamp, creates failed-once, and exits with status 1. Restart=on-failure schedules another execution one second later. The second execution writes another timestamp and remains active in sleep.

Start and enable act on different dimensions. Start changes the current runtime state but does not create an enablement link. Enable creates that link below default.target.wants but does not start an inactive service.

## Boot analysis

systemd-analyze blame sorts units by time spent activating. Its first row is not automatically the cause of the total boot time: the unit may run in parallel with other work, and its duration may be dominated by a deliberate wait.

systemd-analyze critical-chain follows ordering dependencies backward from a target and displays when each unit became active and how long it took. It is more useful for locating delay on that path, but it cannot represent dependencies that were never declared to systemd. The command output must therefore be interpreted together with unit definitions and logs.
