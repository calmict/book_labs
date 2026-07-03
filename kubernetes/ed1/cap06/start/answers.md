# Chapter 6 — Answers

## The ping across the bridge

    # paste here the output of: ping -c 3 10.42.0.3 (from blue)

## The evidence

    # paste here ip neigh (inside blue) and bridge fdb show br br-lab

## The déjà vu on docker0

    # paste here ip link show master docker0 with the lab container running

## The three questions

**a. Why does a veth have TWO ends, and why does one live in the namespace
and the other on the bridge?**

_(your answer)_

**b. Describe the ping's journey (veth-blue → br-lab → veth-red and back)
and explain what ip neigh and the bridge fdb tell you.**

_(your answer)_

**c. The blue namespace can ping red but not the internet: what is it
missing?**

_(your answer)_
