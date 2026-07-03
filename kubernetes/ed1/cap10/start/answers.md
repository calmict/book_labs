# Chapter 10 — Answers

## The professionals' heartbeat

    # paste here holderIdentity and two readings of renewTime
    # from the kube-controller-manager lease

## Your controller at work

    # paste here a few lines of minictl.sh output showing the repair
    # after your sabotage (and the pruning of the extra pod)

## The duel

    # paste here the interleaved decisions of the two copies
    # (the overshoot and, if you caught it, the double delete)

## The three questions

**a. Point at the observe, diff and act lines of your script and map them
onto what the ReplicaSet controller did in chapter 7.**

_(your answer)_

**b. Why does polling not scale, and what do client-go's informers and
cache change?**

_(your answer)_

**c. Describe the duel and how leader election prevents it: who renews the
lease, and what happens if it stops?**

_(your answer)_
