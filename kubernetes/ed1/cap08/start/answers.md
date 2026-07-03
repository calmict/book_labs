# Chapter 8 — Answers

## The three members and their leader

    # paste here: endpoint status --cluster -w table (before the murder)
    # and mark who the leader was

## A namespace is a key

    # paste here the /registry/... key you found for raft-lab

## The election

    # paste here: endpoint status --cluster after stopping the leader
    # (who is the new leader?)

## The frozen cluster

    # paste here the kubectl error with 2 members down,
    # and the healthy output after the resurrection

## The three questions

**a. Why do 3 members tolerate the loss of only 1? How many would a
5-member cluster tolerate? Write the general rule, and explain why 2
members are worse than 1.**

_(your answer)_

**b. Tell the story of the election: who elected the new leader, and on
what basis? Why did Kubernetes keep answering as if nothing happened?**

_(your answer)_

**c. During the freeze, did the containers already running on the surviving
node keep running? Why does a frozen brain not stop the arms?**

_(your answer)_
