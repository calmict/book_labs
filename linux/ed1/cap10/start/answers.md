# Chapter 10 — Observations

## Parent and child

    Parent PID:
    Child PID:
    Child PPID:

Explain which process returns from fork() in each branch and how ps proves their relationship.

## PID across exec

    PID before exec:
    PID after exec:
    Program after exec:

Explain what exec() replaces and what it preserves.

## Zombie lifecycle

    Child state before SIGUSR1:
    Result after SIGUSR1 to the parent:

Explain why acting on the parent removes the zombie, while signaling the zombie itself cannot make it run or exit again.
