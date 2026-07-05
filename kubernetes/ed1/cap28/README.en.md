# Chapter 28 — The Doorman's Passport (Ingress-Nginx and Cert-Manager)

> Exercise for **Chapter 28 — Ingress-Nginx and Cert-Manager: automatic TLS** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Cloud Architect

## Objectives

By the end of this lab you will be able to:

- frame the TLS certificate problem: the doorman (Ingress-Nginx from chapter 19) must prove the building's identity to every visitor over HTTPS, but certificates have to be generated, installed and — above all — they expire;
- stand up an automatic passport office with Cert-Manager: an authority (CA), and certificates issued and renewed on their own;
- get end-to-end HTTPS with a single annotation on the Ingress, and validate the certificate against your CA — understanding where, in production, Let's Encrypt via ACME would step in.

## Prerequisites

- Chapter 19 (Ingress and Ingress Controller: the doorman that routes by host; here we give it a TLS passport). Familiarity with Deployment/Service/Ingress.
- kind installed. WARNING: ingress-nginx and cert-manager install cluster-wide resources (CRDs, webhooks); as in chapters 26–27 the lab uses a dedicated throwaway cluster (book-labs-tls), deleted at the end.
- In start/: issuer.yaml (given, the SelfSigned→CA→CA-issuer chain), app.yaml (given, the shop behind the doorman) and ingress.yaml (TODO, the Ingress to make HTTPS).

## Instructions

1. The passport office. Create the cluster, label the node for the ingress, install the doorman and the office, then build the local authority:

       kind create cluster --name book-labs-tls
       kubectl label node book-labs-tls-control-plane ingress-ready=true
       kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.14.0/deploy/static/provider/kind/deploy.yaml
       kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
       kubectl -n ingress-nginx wait --for=condition=Available deploy/ingress-nginx-controller --timeout=180s
       kubectl -n cert-manager wait --for=condition=Available deploy --all --timeout=180s
       kubectl apply -f issuer.yaml

   issuer.yaml builds the authority: a SelfSigned ClusterIssuer signs a CA certificate (the local root of trust), and a second ClusterIssuer uses that CA to sign the real certificates. In production this authority would be Let's Encrypt via ACME; here, with no public DNS, we are our own authority.

2. A passport asked for on its own. Complete ingress.yaml: add the annotation cert-manager.io/cluster-issuer: local-ca and a tls section naming the host (shop.book-labs.local) and the Secret where the certificate will land (shop-tls). Apply the app and the ingress:

       kubectl apply -f app.yaml
       kubectl apply -f ingress.yaml
       kubectl -n web get certificate,secret shop-tls

   Within seconds Cert-Manager, seeing the Ingress, creates a Certificate object on its own and issues it into the shop-tls Secret (type kubernetes.io/tls). You generated neither a key nor a certificate: the office requested and signed them.

3. The visitor checks the passport. Call the shop over HTTPS, validating against YOUR CA (no -k). The ingress is reachable by ClusterIP: use the in-cluster client with the CA mounted:

       IP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.clusterIP}')
       kubectl -n web exec tlsclient -- curl -sS --cacert /ca/ca.crt --resolve shop.book-labs.local:443:$IP https://shop.book-labs.local/
       kubectl -n web get secret shop-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -issuer -ext subjectAltName

   The response secure shop over HTTPS, and the certificate shows issuer=book-labs-local-ca (your CA) and the SAN shop.book-labs.local, which Cert-Manager filled in on its own by reading the Ingress host. End-to-end HTTPS, automatic and renewable.

4. The full picture (28.4). Doorman + office + authority: an HTTP request reaches the controller and is served over TLS with a certificate nobody made by hand and that Cert-Manager will renew before it expires. In production you just change the issuer from a local CA to an ACME issuer (Let's Encrypt) and the exact same Ingress gets a publicly-valid certificate.

5. Tear the site down:

       kind delete cluster --name book-labs-tls

## The questions for answers.md

- (a) The certificate problem (28.1–28.2). Why does serving HTTPS require a certificate signed by an authority the client trusts, and why is doing it by hand a problem (generation, installation, and above all expiry/renewal)? What role does chapter 19's Ingress-Nginx doorman play here?
- (b) Cert-Manager and ACME (28.3). What does Cert-Manager do when it sees the annotation on the Ingress, and what is the Certificate object? Explain the SelfSigned→CA→leaf chain you built. What is the ACME protocol, and why in production would the authority be Let's Encrypt and not you — what does ACME need (that is missing here) to work?
- (c) The full picture (28.4). Trace a request from the visitor to the shop over HTTPS. Where did the certificate's SAN come from? And what would change, and what would NOT, moving from the local CA to a real ACME issuer?

## Definition of "done"

- [ ] ingress-nginx and cert-manager running; the issuer chain ready (CA Ready).
- [ ] The completed Ingress makes Cert-Manager issue the shop-tls Secret on its own.
- [ ] curl HTTPS validated against the local CA answers secure shop; the certificate has the host's SAN.
- [ ] answers.md answers the three questions; the dedicated cluster has been deleted.
