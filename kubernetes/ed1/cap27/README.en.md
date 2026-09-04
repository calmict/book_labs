# Chapter 27 — The Escort

**Level:** Cloud Architect

After entrusting state to an auditor, you entrust every call to an escort that applies identity, encryption, and routing without changing the application.

## Objectives

- Observe sidecars, the data plane, and the control plane (27.1, 27.2).
- Enforce automatic mTLS and workload identity (27.3).
- Direct an 80/20 canary and connect the mesh to observability (27.4, 27.5).

## Prerequisites

- kind, Docker, kubectl, and istioctl available; at least 3 GB free in Docker storage.
- Internet access for images; chapters 22 and 25 completed.

## The scenario

Complete TODOs 1..3: enable injection, enforce STRICT, and assign the 80/20 weights. The test uses the dedicated book-labs-mesh cluster because Istio installs cluster-wide CRDs and a webhook.

    cd kubernetes/ed1/cap27/solution
    ./run.sh

### Phase 1 — Attach the escort (27.1, 27.2)

The namespace label makes every workload start with its application and istio-proxy.

### Phase 2 — Verify identity and encryption (27.3)

Contrast a plaintext call before and after PeerAuthentication STRICT; the in-mesh client continues to pass.

### Phase 3 — Direct traffic (27.4, 27.5)

DestinationRule defines the versions and VirtualService divides requests 80/20 without modifying the application.

## Definition of "done"

- [ ] The three TODOs are complete and every workload has a sidecar.
- [ ] STRICT rejects plaintext but permits in-mesh traffic.
- [ ] The canary reaches both versions.
- [ ] run.sh prints OK 1..4 — or a reasoned SKIP 1 — and ALL CHECKS PASSED.

## How it is verified

- OK 1 verifies the dedicated cluster and control plane.
- OK 2 counts two containers in each of the three workloads.
- OK 3 is the biting gate: plaintext passes before STRICT and is rejected afterward, while mTLS passes.
- OK 4 sends sixty requests and verifies that both subsets receive traffic.

## Reflection questions

**a.** What changes when network logic moves into sidecars, and how do the data and control planes divide the work?

**b.** Where do mTLS identities and certificates come from, and how do they complement NetworkPolicy?

**c.** How does the mesh apply canaries, retries, circuit breaking, and observability without code changes?

## Cleanup

run.sh always deletes the dedicated book-labs-mesh cluster and restores the previous kubectl context.

## Where this leads

The service mesh closes the operational journey: state, security, traffic, and signals are governed by the platform; the appendices provide references for continuing.
