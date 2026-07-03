# Chapter 7 — Answers

## The brain, component by component

    # paste here the kube-system pods and mark the 4 control plane components

## The sabotage

    # paste here the kubectl get pods -w sequence: the deleted Pod
    # and its replacement being born

## Desired vs observed

    # paste here the spec.replicas and status.readyReplicas lines
    # from the Deployment YAML

## The three questions

**a. List the control plane components with each one's role in a sentence.
Why is the kubelet not among the Pods?**

_(your answer)_

**b. Tell the story of step 4 from the controller's point of view: what did
it compare, what did it decide, who materially created the new Pod?**

_(your answer)_

**c. Who writes the spec and who writes the status? Why is this separation
the heart of the declarative model?**

_(your answer)_
