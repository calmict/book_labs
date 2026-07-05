# Chapter 28 — Answers (model solution)

## The certificate, issued automatically

    CERT       READY   SECRET
    shop-tls   True    shop-tls

    NAME              TYPE                DATA   AGE
    secret/shop-tls   kubernetes.io/tls   3      3s

## HTTPS validated against the local CA

    https://shop.book-labs.local/ -> secure shop
    issuer=CN=book-labs-local-ca
    X509v3 Subject Alternative Name: critical
        DNS:shop.book-labs.local

## The three questions

**a. The certificate problem (28.1-28.2): why does HTTPS need a certificate
from a trusted authority, why is doing it by hand a problem (especially
renewal), and what role does the Ingress-Nginx doorman play?**

HTTPS is TLS, and TLS gives the client two things: encryption and IDENTITY.
Encryption alone is worthless if you cannot be sure who you are encrypting
to — otherwise an attacker in the middle just presents their own key. So the
server must present a certificate binding its hostname to a public key, and
that certificate must be SIGNED by a certificate authority the client already
trusts (the CA roots shipped in browsers and OSes). The client checks the
signature and the hostname (the SAN), and only then trusts the connection.
Doing this by hand is painful on every axis: you generate a key and a CSR,
get it signed, install the resulting certificate into the server, and — the
part that actually bites in production — you must RENEW it before it expires
(Let's Encrypt certs last 90 days), or the site goes dark. Multiply by every
host and every renewal and it becomes a recurring outage waiting to happen.
The Ingress-Nginx doorman (chapter 19) is where TLS is terminated: it is the
single edge that faces visitors, routes by host, and presents the
certificate — so it is exactly the place that needs one, per host.

**b. Cert-Manager and ACME (28.3): what does Cert-Manager do on the
annotation, what is the Certificate object, explain the SelfSigned->CA->leaf
chain, and what is ACME (and what does it need that is missing here)?**

Cert-Manager is a controller that watches for the
cert-manager.io/cluster-issuer annotation (and the tls block) on Ingresses.
When it sees ours, it creates a CERTIFICATE object on its own — a declarative
resource that says "I want a cert for shop.book-labs.local, stored in Secret
shop-tls, signed by issuer local-ca" — then does the whole dance: generates
the key, builds the request, gets it signed by the issuer, and writes the
resulting key+cert into the Secret (type kubernetes.io/tls) that Ingress-Nginx
mounts. It also tracks expiry and re-issues before the deadline: automatic
renewal is the real win. The chain we built has three links: a SelfSigned
ClusterIssuer (an issuer that signs with no authority above it, used only to
bootstrap), a CA Certificate signed by it (our local root of trust), and a CA
ClusterIssuer that uses that root to sign the actual leaf certificates for our
hosts. ACME is the protocol Let's Encrypt speaks: instead of you being the
authority, a public CA issues the cert AFTER verifying you really control the
domain — via a challenge (HTTP-01: serve a token at
http://your-domain/.well-known/..., or DNS-01: publish a TXT record). That
verification is exactly what is missing here: ACME needs a PUBLIC domain name
and a publicly reachable endpoint (or controllable public DNS) so the CA can
run the challenge. On a local kind cluster with a made-up host and no public
DNS, there is nothing for Let's Encrypt to verify, so we run our own CA.

**c. The full picture (28.4): trace a request over HTTPS, where the SAN came
from, and what would change (and what would not) moving to a real ACME
issuer.**

A visitor opens https://shop.book-labs.local/. The TLS handshake reaches the
Ingress-Nginx controller, which presents the shop-tls certificate from the
Secret cert-manager filled; the client validates it against the CA it trusts
(here our local CA, mounted as ca.crt) — checking the signature and that the
SAN matches the hostname — then the encrypted request is routed by the
Ingress rule to the shop Service and its pod, which returns "secure shop". The
certificate's SAN, shop.book-labs.local, came from cert-manager reading the
host out of the Ingress's tls/rules automatically — you never typed it into a
CSR. Moving to a real ACME issuer changes almost nothing in what you write:
the same Ingress, the same annotation, the same tls block — you only swap the
issuer from our CA ClusterIssuer to an ACME ClusterIssuer pointing at Let's
Encrypt. What changes underneath is the authority and the trust: the cert
would be signed by Let's Encrypt (trusted by every browser out of the box, so
no -k and no custom CA), and issuance would require passing an ACME challenge,
which needs the public domain and reachability described above. Everything
else — cert-manager creating the Certificate, issuing into a Secret, renewing
before expiry, and the doorman serving it — stays exactly the same.
