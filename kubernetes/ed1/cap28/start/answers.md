# Chapter 28 — Answers

## The certificate, issued automatically

    # paste here: shop-tls Certificate Ready=True and the shop-tls Secret

## HTTPS validated against the local CA

    # paste here: the "secure shop" response, and the cert's issuer + SAN

## The three questions

**a. The certificate problem (28.1-28.2): why does HTTPS need a certificate
from a trusted authority, why is doing it by hand a problem (especially
renewal), and what role does the Ingress-Nginx doorman play?**

_(your answer)_

**b. Cert-Manager and ACME (28.3): what does Cert-Manager do on the
annotation, what is the Certificate object, explain the SelfSigned->CA->leaf
chain, and what is ACME (and what does it need that is missing here)?**

_(your answer)_

**c. The full picture (28.4): trace a request over HTTPS, where the SAN came
from, and what would change (and what would not) moving to a real ACME
issuer.**

_(your answer)_
