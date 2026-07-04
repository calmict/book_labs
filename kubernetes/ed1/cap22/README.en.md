# Chapter 22 — The Vault and the Corridor (NetworkPolicy and Zero-Trust)

> Exercise for **Chapter 22 — NetworkPolicy and the Zero-Trust Approach** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Advanced

## Objectives

By the end of this lab you will be able to:

- feel the default-allow problem: in the Kubernetes condo every pod reaches every pod, vault included;
- invert the rule with a three-line default deny, then reopen ONLY the right door: labels as firewall rules, ports as a contract;
- close the exit too (egress): a vault that receives but never phones out — and discover who actually realises the policies (the CNI), with the enforcement test as a hygiene habit.

## Prerequisites

- Chapters 18 and 21 completed (Services and least privilege: here least privilege reaches the network).
- The book-labs cluster running. WARNING: NetworkPolicies are realised by the CNI — recent kind enforces them; standard minikube does NOT (it needs minikube start --cni=calico). Step 2 includes the test that tells you immediately.
- Four manifests in start/: pods.yaml and deny-all.yaml (given), allow-app.yaml and no-exfiltration.yaml (TODO).

## Instructions

1. The open corridor. Create the lab namespace and the three tenants:

       kubectl create namespace vault
       kubectl apply -f pods.yaml
       kubectl -n vault get pods --show-labels

   safe (the vault, label app=safe, serving the jewels on 8080), app (role=app, the legitimate application) and guest (no role). Try BOTH accesses:

       SAFE=$(kubectl -n vault get pod safe -o jsonpath='{.status.podIP}')
       kubectl -n vault exec app -- wget -T 3 -qO- http://$SAFE:8080
       kubectl -n vault exec guest -- wget -T 3 -qO- http://$SAFE:8080

   Jewels for everyone: default allow. Nobody ever authorised anything — simply, nobody ever forbade.

2. The inversion. deny-all.yaml is already written (read it: empty podSelector = every pod in the namespace, policyTypes Ingress, no rules = no entry). Apply it and redo both wgets:

       kubectl apply -f deny-all.yaml
       kubectl -n vault exec app -- wget -T 3 -qO- http://$SAFE:8080
       kubectl -n vault exec guest -- wget -T 3 -qO- http://$SAFE:8080

   Timeout for both: the corridor is walled up. This is also the ENFORCEMENT TEST: if the jewels still flow, your CNI is ignoring the policies (the object with no executor — chapter 19 déjà vu) and you must change it before going on.

3. The door with a nameplate. Complete allow-app.yaml: a policy selecting the vault (app=safe) that admits ingress ONLY from role=app pods, ONLY on TCP port 8080. Apply and try both again:

       kubectl apply -f allow-app.yaml
       kubectl -n vault exec app -- wget -T 3 -qO- http://$SAFE:8080
       kubectl -n vault exec guest -- wget -T 3 -qO- http://$SAFE:8080

   app gets in, guest stays out. Note the grammar: policies are ADDITIVE — you wrote a permission, never an explicit prohibition; the prohibition is the silence.

4. The vault makes no calls. Complete no-exfiltration.yaml: a policy on app=safe, policyTypes Egress, no egress rules at all. Apply and try the outgoing call:

       kubectl apply -f no-exfiltration.yaml
       APP=$(kubectl -n vault get pod app -o jsonpath='{.status.podIP}')
       kubectl -n vault exec safe -- wget -T 3 -qO- http://$APP:8080

   Timeout: whoever cracks the vault carries nothing out. (Professional warning: an egress deny blocks DNS too — here we used raw IPs; in the real world you reopen port 53 towards kube-dns.)

5. The questions for answers.md: (a) from default allow to default deny: why is the flat network THE problem, what exactly does the empty podSelector say, and why does the policy grammar contain only permissions (the deny is the silence)? (b) read your three policies as a network contract: who talks to whom, on which port — and what would it take to let guest in: changing the policy or... changing its label? Reflect on what that says about the model; (c) who realises the policies? Tell the enforcement test and the chapter 19 déjà vu, explain the CNI's role (22.4) and the DNS caveat of the egress deny.

6. Tear the vault down:

       kubectl delete namespace vault

## Definition of "done"

- [ ] Before any policy: jewels for everyone (default allow, felt firsthand).
- [ ] With deny-all: timeout for everyone — and the enforcement test passed.
- [ ] With allow-app: app in, guest out; with no-exfiltration: the vault makes no calls.
- [ ] answers.md answers the three questions.
- [ ] The vault namespace has been deleted.
