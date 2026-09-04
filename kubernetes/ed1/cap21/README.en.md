# Chapter 21 — The Intern and the Robot

**Level:** Advanced

Storage separated request from implementation; now you separate authentication from authorization.
You hire a person with a certificate and give a workload an identity of its own.

## Objectives

- Create a user identity with a key, CSR, certificate, and dedicated kubeconfig (21.1).
- Give a Pod a ServiceAccount and use its mounted token to call the API (21.2).
- Apply least-privilege Role and RoleBinding objects and verify their boundaries (21.3, 21.4).

## Prerequisites

- The book-labs cluster reachable through kubectl and openssl installed on the host.
- An administrative identity allowed to approve CSRs and create RBAC objects.
- Chapter 9 completed for authentication, authorization, and the API Server.

## The scenario

Complete TODOs 1..3: the minimum Role and human binding, the ServiceAccount worn by the Pod, and the
robot's binding. run.sh creates namespace lab-cap21 and temporary files for the key and kubeconfig.

    cd kubernetes/ed1/cap21/solution
    ./run.sh

### Phase 1 — Hiring the intern (21.1)

The test generates a key, submits a CertificateSigningRequest with CN stagista and group tirocinanti,
approves it, and builds a kubeconfig. No User object is created: the identity lives in the certificate.

### Phase 2 — The minimum job description (21.3, 21.4)

Before the binding, the authenticated intern receives Forbidden. After it, she can read Pods in
lab-cap21 but cannot create them, read Secrets, or cross the namespace boundary.

### Phase 3 — The robot (21.2, 21.3)

The Pod uses its own ServiceAccount token to call the API. The same request returns 403 before the
binding and a PodList afterward: the counterexample isolates the permission just added.

## Definition of "done"

- [ ] The three TODOs are complete.
- [ ] The intern is recognized and remains confined to her job description.
- [ ] The robot changes from 403 to PodList only after the binding.
- [ ] run.sh prints OK 1..6 and ALL CHECKS PASSED.

## How it is verified

- OK 1 verifies the name and group in the signed certificate.
- OK 2 is the first gate: authentication without authorization remains denied.
- OK 3 verifies the granted verbs on Pods.
- OK 4 verifies verb, resource, and namespace boundaries.
- OK 5 is the second gate: the robot receives 403 without its binding.
- OK 6 verifies the PodList through the mounted token after binding.

## Reflection questions

**a.** Where does the intern exist, why are human users not API objects, and what does that mean for revocation?

**b.** How do you read the Role as a verb-resource-namespace triple, and which wall stops each denied request?

**c.** How do a human certificate and a ServiceAccount token differ, and why should each workload have
a distinct identity?

## Cleanup

run.sh deletes the CSR, namespace lab-cap21, and the temporary directory holding the key, certificate,
and kubeconfig. It leaves no credentials in the repository.

## Where this leads

You crossed authentication and authorization separately. Later chapters use these boundaries to
protect configuration, secrets, and communication between workloads.
