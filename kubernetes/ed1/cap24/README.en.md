# Chapter 24 — The Mould and the Casts

**Level:** Cloud Architect

You have coordinated Kubernetes objects by hand; now one chart turns their shared shape into a versioned release.

## Objectives

- Contrast repeated static manifests with a reusable chart (24.1).
- Render templates with release data and values (24.2).
- Install, upgrade, inspect, and roll back a release (24.3, 24.4).

## Prerequisites

- kubectl and helm available, with a reachable cluster.
- Chapter 15 completed and familiarity with Deployment, Service, and ConfigMap.

## The scenario

Compare start/plain.yaml with the chart, then complete TODOs 1..3: release-derived names,
values-driven settings, and the config checksum that makes rollout deterministic.

    cd kubernetes/ed1/cap24/solution
    ./run.sh

### Phase 1 — Build the mould (24.1, 24.2)

helm lint and helm template must turn one chart plus its default values into concrete manifests without touching the cluster.

### Phase 2 — Two numbered casts (24.3)

Install revision 1, then upgrade replicas and message. The checksum changes the Pod template and causes a real rollout.

### Phase 3 — Return to the earlier cast (24.3, 24.4)

Roll back to revision 1 and inspect the three revisions stored as Secrets in the release namespace.

## Definition of "done"

- [ ] The three TODOs are complete and the chart renders cleanly.
- [ ] Upgrade changes replicas and message through a deterministic Pod rollout.
- [ ] Rollback restores revision one and preserves three history entries.
- [ ] run.sh prints OK 1..4 and ALL CHECKS PASSED.

## How it is verified

- OK 1 verifies lint and default rendering.
- OK 2 verifies the installed state and served content of revision 1.
- OK 3 is the biting gate: the checksum change replaces the old Pod while applying revision 2.
- OK 4 verifies coordinated rollback and the three stored revision Secrets.

## Reflection questions

**a.** What belongs to templates, values, and release data, and what does helm template reveal before installation?

**b.** What are releases and revisions, and why does checksum/config cause a rollout while a ConfigMap change alone does not?

**c.** What is a chart repository, and when would you build a chart rather than install an existing one?

## Cleanup

run.sh uninstalls greeter and deletes namespace helmlab, including on failure.

## Where this leads

Helm gives the platform versioned packages. The next chapters install and operate observability components built this way.
