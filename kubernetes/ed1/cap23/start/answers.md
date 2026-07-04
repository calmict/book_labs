# Chapter 23 — Answers

## The naked king

    # paste here: id, CapEff, Seccomp and the writable root of the plain pod

## The stripped king

    # paste here: id, CapEff (zeros), Seccomp 2 and the read-only refusal

## The checkpoint

    # paste here: the admission refusal of the root intruder,
    # and the hardened pod admitted under restricted

## The three questions

**a. SecurityContext and the shared kernel (23.1-23.2): why is container
root still dangerous, what does CapEff tell you, and what does each
defence protect?**

_(your answer)_

**b. Seccomp and MAC (23.3-23.4): what does the Seccomp field mean, what
does RuntimeDefault do, and how does seccomp differ from AppArmor/SELinux?
Why is neither on by default?**

_(your answer)_

**c. Pod Security Standards (23.5): the three levels and three modes, why
the label did not evict the running king, and the parallel with
chapter 22 (defence pod-by-pod versus defence at scale).**

_(your answer)_
