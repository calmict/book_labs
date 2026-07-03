# Chapter 3 — Answers

## CPU: free vs caged

    # paste here the %CPU of the loop before the cage
    # and the top output after entering the cage

## cpu.stat after a while in the cage

    # paste here nr_throttled and throttled_usec

## Memory: the evidence of the murder

    # paste here memory.events, memory.peak
    # and the last dmesg lines after the glutton was killed

## The three questions

**1. Why does the CPU limit slow down without killing, while the memory limit
kills? (hint: compressible vs incompressible resource)**

_(your answer)_

**2. What do cpu.max and memory.max correspond to in the Kubernetes world,
and where does a Pod's OOMKilled status come from?**

_(your answer)_

**3. What do nr_throttled and oom_kill tell whoever is troubleshooting?**

_(your answer)_
