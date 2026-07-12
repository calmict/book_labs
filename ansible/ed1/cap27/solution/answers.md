# Chapter 27 - Answers (model solution)

## The three TODOs

    # TODO 1 (27.2) - the play: apply in waves, not all at once
    serial: 2

    # TODO 3 (27.5) - the play: the emergency brake
    max_fail_percentage: 25

    # TODO 2 (27.4) - the play: put the node back in the pool (the forgotten half)
    post_tasks:
      - name: Put the host back in the pool
        ansible.builtin.shell: 'echo "$(date +%s%N) ENABLE {{ inventory_hostname }}" >> {{ ledger }}'
        delegate_to: "{{ lb_host }}"
        changed_when: false

solution/run.sh proves all three, locally and offline, by reading the balancer's pool ledger. On the
healthy run every one of the 6 nodes is drained, updated and re-enabled, and at no instant are more
than 2 (serial) out of the pool - the choreography and the wave size, TODO 1 and TODO 2. Then it runs
the rollout with one node set to fail its update: the play stops after the first wave and the rest of
the farm is never touched - the brake, TODO 3. Finally it widens the wave to the whole farm and shows
all 6 going down at once - the outage that serial exists to prevent.

## The three questions

**a. Choosing serial on a real fleet, and fixed number vs percentage.**

serial is capacity arithmetic. During a rolling update the pool runs with (N - wave) nodes, so the
question is simply: how many nodes can I remove and still serve peak load? If the farm holds peak only
with at least 80% of its nodes, then at most 20% may be out at once, and that is your ceiling: on a
6-node farm, serial 1 (a wave of one keeps 5/6 = 83% up); serial 2 would drop to 4/6 = 67%, below the
line. The choice between a fixed number and a percentage is about what happens as the farm grows. serial: 2
is an absolute promise - always exactly two out - so as the farm scales from 6 to 600 those two become
a vanishing fraction and the rollout crawls (300 waves). serial: "20%" scales with the fleet - it
always removes the same share, so it keeps the same safety margin and the same number of waves whatever
the size. Fixed numbers are right when the constraint is absolute (a downstream system tolerates only N
concurrent reconnections); percentages are right when the constraint is proportional (keep 80% of
capacity), which is the common case, and they are why serial accepts "50%" as readily as 3. A list,
serial: [1, "20%"], gets both: a single-node canary first, then proportional waves.

**b. Why a small serial is itself recovery safety, and always vs plain post_tasks.**

Because the brake stops propagation but not the wound: when max_fail_percentage trips, the wave that
was in flight is left half-done - drained, maybe half-updated, not yet re-enabled. The size of that
mess is exactly the size of the wave. With serial 2, at most two nodes are stranded out of the pool
when the rollout halts; with "all at once", the whole farm is stranded. So a small serial bounds the
blast radius by construction: less to notice, less to repair, and the rest of the fleet provably
untouched. That is recovery safety you get for free, before writing any recovery logic. The always
block is the second half. Plain post_tasks run only if the tasks before them succeeded - so exactly
when an update fails (the case you care about), the re-enable in post_tasks is skipped and the node is
left drained. Wrapping drain+update in a block with the re-enable in always inverts that: always runs
whether the update succeeded or failed, so a node that breaks mid-update is still returned to a known
state (back in the pool, or explicitly kept out and flagged) instead of silently vanishing from
capacity. post_tasks re-enable is right for the happy path; always is what makes the choreography
survive the unhappy one.

**c. Why drain/enable must delegate_to the balancer.**

Because taking a node out of rotation is an action on the thing that routes traffic - the load
balancer - not on the node being updated. The play runs "on" the web host (that is where the release
is applied), but inventory_hostname is the *subject* of the change, not the place every step must
execute. delegate_to keeps the subject (this web node) while moving the *execution* to the balancer, so
"stop sending traffic to web3" is carried out by the component that actually controls traffic. Remove
delegate_to and the drain runs on web3 itself, and it breaks in two ways. First, it is aimed at the
wrong machine: web3 has no authority over the balancer's routing table, so telling web3 to remove web3
does nothing to the traffic - clients keep hitting a node you are busy restarting, which is the exact
outage the drain was meant to prevent. Second, it races the update: the moment you restart or take down
the service on web3 to update it, any "remove me from the pool" command still running there dies with
it. The drain has to happen from a vantage point that stays up and stays in control while the target
goes down - and that vantage point is the balancer. It is the difference between the stage manager
dimming a musician's mic from the booth and asking the musician to dim their own mic while walking off
stage.
