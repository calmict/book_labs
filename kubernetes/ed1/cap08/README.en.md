# Chapter 8 — Kill the Leader: Quorum and Elections in etcd

> Exercise for **Chapter 8 — Etcd and Distributed Consensus** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- start a cluster with 3 control planes and query the 3 etcd members that hold its memory;
- see that every Kubernetes object is literally a key inside etcd (/registry/...);
- assassinate the leader and witness the successor's election, with the cluster not missing a beat;
- break the quorum and experience firsthand what "the cluster is frozen" means — then bring it back to life.

## Prerequisites

- Chapter 7 completed (the cluster and the declarative model).
- **kind** and Docker: this chapter requires kind (minikube does not support multiple control planes); kind nodes are Docker containers, and that will become our weapon.
- About 4 GB of free RAM: the 3-node HA cluster is the heaviest of the series so far.
- The configuration file is provided in start/kind-ha.yaml.

> ⚠️ If the creation fails with the node join timing out (an etcd learner
> that never starts) or "too many open files" errors, your host's inotify
> limits are too low for 3 nodes: see the Troubleshooting section of
> [SETUP.md](../../SETUP.md).

## Instructions

1. Create the dedicated 3-control-plane cluster (from the exercise folder):

       kind create cluster --config start/kind-ha.yaml
       kubectl get nodes

   Three control-plane nodes (and a load balancer appeared in Docker too: kind adds it by itself to spread requests across the 3 apiservers).

2. The memory is now threefold: three etcd pods, one per node. Prepare the wrench to interrogate them (etcdctl inside the pod, with the cluster certificates):

       kubectl get pods -n kube-system | grep etcd
       ETCD="kubectl exec -n kube-system etcd-book-labs-ha-control-plane -- etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key"
       $ETCD member list -w table
       $ETCD endpoint status --cluster -w table

   In the IS LEADER column there is exactly one true: note down who rules, and on which IP.

3. Kubernetes literally lives in here. Create an object and find it again as a key:

       kubectl create namespace raft-lab
       $ETCD get /registry/namespaces/raft-lab --keys-only
       $ETCD get /registry/namespaces --prefix --keys-only

   Every kubectl create of chapter 7 was nothing but a put on this database.

4. The murder. Find out which node hosts the leader (match the leader's IP against kubectl get nodes -o wide) and freeze it — kind nodes are containers, and we will pause them instead of stopping them (on a restart Docker may reassign the IPs, and etcd member identities are tied to the IPs):

       kubectl get nodes -o wide
       docker pause <the-leader-node>

   Now interrogate a survivor (update ETCD with the name of a living etcd pod) and look at the election that already happened:

       $ETCD endpoint status --cluster -w table

   A new leader, elected in a fraction of a second. And the cluster? kubectl get nodes still works: 2 out of 3 is a majority, democracy holds.

5. Breaking the quorum. Freeze a second node (one of the two survivors) and try again:

       docker pause <second-node>
       kubectl get namespaces --request-timeout=5s

   Error: with 1 member out of 3 there is no majority, and without a majority etcd answers neither writes nor consistent reads. The cluster is not dead: it is frozen, waiting to be able to guarantee the truth again.

6. The resurrection: unfreeze the two nodes and verify the return to normality:

       docker unpause <the-leader-node> <second-node>
       kubectl get namespaces
       $ETCD endpoint status --cluster -w table

   Three members, one leader, and the raft-lab namespace never lost: it was replicated on all of them.

   The three questions for answers.md: (a) why do 3 members tolerate the loss of only 1? How many would a 5-member cluster tolerate? Write the general rule, and explain why 2 members are worse than 1. (b) tell the story of the step 4 election: who elected the new leader, and on what basis? Why did Kubernetes keep answering as if nothing happened? (c) during the step 5 freeze, did the containers already running on the surviving node keep running? Why does a frozen brain not stop the arms?

7. Tear down the lab (only the HA cluster: the chapter 7 one remains yours):

       kind delete cluster --name book-labs-ha

## Definition of "done"

- [ ] You saw 3 etcd members with exactly one IS LEADER=true and noted who it was.
- [ ] You found the raft-lab namespace as a /registry/... key inside etcd.
- [ ] After pausing the leader you saw a new leader and kubectl still working.
- [ ] With 2 nodes frozen you got the lost-quorum error, and after the unpause the cluster came back whole, raft-lab included.
- [ ] answers.md answers the three questions and the book-labs-ha cluster has been deleted.
