# Chapter 15 — Answers

## The release

    # paste here a fragment of the pod-by-pod watch, and the two
    # ReplicaSets (3 and 0) after the rollout

## The disaster

    # paste here the stuck state: the ImagePullBackOff scout AND the
    # three old pods still Running

## The comeback

    # paste here the image after the undo and the rollout history
    # with the change-causes

## The three questions

**a. What does the ReplicaSet do, and what can only the Deployment do?
Why do old ReplicaSets stay at 0 instead of disappearing?**

_(your answer)_

**b. Why did the service never go down during the disaster, and what would
have changed with maxUnavailable 1? Who notices such a problem in
production?**

_(your answer)_

**c. What does rollout undo really do, in terms of scaled ReplicaSets?**

_(your answer)_
