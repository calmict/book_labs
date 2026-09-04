# Chapter 28 — The Doorman's Passport

**Level:** Cloud Architect

The journey ends by giving the doorman hired in chapter 19 a verifiable identity. In this lab you build
a local CA, ask Cert-Manager to issue a certificate, and prove that Ingress-Nginx serves the shop over
HTTPS without any hand-made keys or certificates.

## Objectives

- Frame TLS certificate acquisition, expiry, and renewal (28.2).
- Observe the SelfSigned, CA, and leaf-certificate chain managed by Cert-Manager (28.3).
- Obtain automatic HTTPS through the Ingress annotation and tls section (28.4).
- Verify the issuer, SAN, and application response through Ingress-Nginx (28.1, 28.4).

## Prerequisites

- Docker, kind, kubectl, OpenSSL, and network access.
- At least 3 GiB free in the filesystem used by Docker; run.sh performs this precheck before creating
  the cluster.
- Familiarity with Deployments, Services, and Ingresses, particularly chapter 19.
- The lab uses the dedicated throwaway cluster book-labs-tls. It neither uses nor modifies the main
  cluster for the handbook.

## The scenario

The local authority and shop are already laid out in start/. start/ingress.yaml routes HTTP traffic,
but three facts are missing: which authority must issue the certificate, which hostname it must cover,
and which Secret must store it.

### Phase 1 — The local authority (28.3)

issuer.yaml creates a SelfSigned ClusterIssuer, the local CA certificate, and the ClusterIssuer that
uses that CA. In production you would use an ACME issuer and a publicly verifiable domain instead; the
subsequent reconciliation would remain the same.

### Phase 2 — The automatic request (28.4 — TODO 1)

In start/ingress.yaml, complete TODO 1 by adding the annotations map and selecting the local-ca
ClusterIssuer. This is the signal asking Cert-Manager to obtain the certificate.

### Phase 3 — Identity and storage (28.4 — TODO 2 and TODO 3)

Complete the tls section: in TODO 2 put shop.book-labs.local in the hosts list, because the SAN must
match the visited name; in TODO 3 set shop-tls as the secretName, the meeting point between
Cert-Manager and Ingress-Nginx.

Compare your result with solution/ingress.yaml, then run the complete check:

    bash solution/run.sh

The script creates the dedicated cluster, installs pinned ingress-nginx and Cert-Manager versions,
tests the incomplete Ingress first, and then applies the solution.

## Definition of "done"

- TODOs 1..3 describe the authority, TLS hostname, and Secret.
- The local CA and the shop-tls Certificate are Ready.
- The HTTPS call validated against the local CA returns secure shop.
- run.sh prints OK 1..5 and ALL CHECKS PASSED, including the contrast without the annotation and tls
  section.

## How it is verified

solution/run.sh verifies, point by point:

- **OK 1** — the SelfSigned chain produces a Ready CA ClusterIssuer.
- **OK 2** — the gate bites: the incomplete Ingress produces neither a Certificate nor shop-tls Secret.
- **OK 3** — the completed Ingress makes Cert-Manager create a Ready Certificate and TLS Secret.
- **OK 4** — Ingress-Nginx serves secure shop over HTTPS and the client trusts the local CA.
- **OK 5** — the certificate contains the requested SAN and is signed by the local CA.

## Reflection questions

**a.** Why does HTTPS require a certificate signed by a trusted authority, why does manual management
become fragile at renewal time, and what role does Ingress-Nginx play (28.1–28.2)?

**b.** What does Cert-Manager create after reading the annotation and tls section? Explain the
SelfSigned, CA, and leaf chain, then identify the validation that ACME would require in production
(28.3).

**c.** Trace an HTTPS request from the client to the Pod: where does the SAN come from, and what changes
when moving to a real ACME issuer without changing the declarative mechanism (28.4)?

Model answers are in solution/answers.md.

## Cleanup

The run.sh trap deletes the book-labs-tls cluster even after an error and restores the previous kubectl
context. If you perform the steps manually, run:

    kind delete cluster --name book-labs-tls

## Where this leads

You have completed the path from a Pod to automatic HTTPS: Service, Ingress, controller, Certificate,
and Secret now form one reconciled cycle. The handbook appendices become the reference tools for
applying and troubleshooting this complete picture in daily work.
