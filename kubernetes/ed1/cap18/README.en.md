# Chapter 18 — The Address That Does Not Exist (Services and kube-proxy)

> Exercise for **Chapter 18 — Services and the Magic of kube-proxy** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Intermediate

## Objectives

By the end of this lab you will be able to:

- feel the problem Services solve: ephemeral Pods, IPs that change at every rebirth;
- use a stable, balanced ClusterIP — then unmask it: it exists on no interface, it is an iptables trick (DNAT plus a netfilter coin, chapter 6 in full glory);
- follow the chain that keeps the list fresh: EndpointSlice noticing every birth and death, and CoreDNS giving it all the only truly stable name.

## Prerequisites

- Chapters 6, 12 and 16 in your toolbox (iptables, readiness, headless).
- The book-labs cluster running; node access via docker exec (kind, or minikube on the Docker driver).
- The start/helpdesk.yaml manifest with the TODO on the Service.

## Instructions

1. The problem. In start/helpdesk.yaml the Deployment is already given: two operators answering with their own name (busybox httpd serving the hostname). Apply and try calling them by IP:

       kubectl apply -f helpdesk.yaml
       kubectl get pods -l app=helpdesk -o wide

   Note the IPs. Now create a client and call the first operator at its direct number:

       kubectl run client --image=busybox:stable -- sleep infinity
       kubectl exec client -- wget -qO- http://<first-pod-ip>:8080

   It answers. But delete that pod, wait for the replacement and look at the IPs again: the direct number died with it. Whoever saves Pods' direct numbers has already lost.

2. The switchboard. Complete the Service TODO in the manifest: selector app=helpdesk, port 80 towards 8080. Re-apply and call the switchboard, several times:

       kubectl get service helpdesk
       kubectl exec client -- wget -qO- http://helpdesk
       kubectl exec client -- wget -qO- http://helpdesk
       kubectl exec client -- wget -qO- http://helpdesk

   One stable IP (the CLUSTER-IP), one name, and answers alternating between the two operators: balancing included.

3. The investigation: that IP does not exist. Search for the ClusterIP on the node's interfaces:

       CIP=$(kubectl get svc helpdesk -o jsonpath='{.spec.clusterIP}')
       NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
       docker exec $NODE ip addr | grep $CIP

   Nothing. No interface, on any node, owns that address. Yet wget works. The trick lives where chapter 6 taught you to look:

       docker exec $NODE iptables-save | grep helpdesk

   There they are: your Service's KUBE-SVC chain, the rules with --probability (the coin!), and the KUBE-SEP ones with the DNAT to the pods' real IPs. The ClusterIP is not a place: it is a destination rewrite, decided by a netfilter coin toss, on every node. (If the grep finds nothing, your kube-proxy speaks nftables: same trick, different dialect — docker exec $NODE nft list ruleset.)

4. Who updates the phonebook. The list of real numbers lives in the EndpointSlices:

       kubectl get endpointslices -l kubernetes.io/service-name=helpdesk -o wide

   Scale to 3 and look again:

       kubectl scale deployment helpdesk --replicas=3
       kubectl get endpointslices -l kubernetes.io/service-name=helpdesk -o wide

   The phonebook chases the Pods in real time: it is the usual watch (chapter 9) — the EndpointSlice controller updates the list, kube-proxy on every node translates it into iptables. Remember chapter 12's bench? It was this phonebook emptying.

5. The name, the only stable thing. Ask CoreDNS:

       kubectl exec client -- nslookup helpdesk.default.svc.cluster.local

   It resolves to the ClusterIP — not to the Pods' IPs (compare with chapter 16's diary: there, headless, DNS gave the individuals' IPs). Stability hierarchy: Pod IPs (ephemeral) < ClusterIP (stable while the Service lives) < DNS name (stable by contract).

   The questions for answers.md: (a) reconstruct a packet's journey from client to operator: who rewrites what, where the DNAT happens, and why the ClusterIP must not exist on any interface; (b) netfilter's coin: how do you read the --probability rule with 2 and with 3 backends, and what happens to the phonebook (and hence to iptables) when a pod dies or fails its readiness? (c) the stability hierarchy: normal versus headless Service (chapter 16) — what does DNS resolve in each case, and when do you want one or the other?

6. Tear down the lab:

       kubectl delete -f helpdesk.yaml
       kubectl delete pod client

## Definition of "done"

- [ ] You experienced the death of the direct number (pod IP changed after the rebirth).
- [ ] The switchboard answers with both voices (balancing seen through repeated wgets).
- [ ] You have the proof that the ClusterIP exists on no interface, plus the KUBE-SVC/KUBE-SEP rules with probability and DNAT.
- [ ] You watched the EndpointSlices chase the scale, and DNS resolve the name to the ClusterIP.
- [ ] answers.md answers the three questions and the lab is torn down.
