# Chapter 2 — Answers

## Process tree seen from inside (ps aux)

    # paste here the output of ps aux inside the container

## Hostname: container vs host

    # paste here the two hostnames side by side

## Namespace inodes: container vs host

    # paste here the two outputs of the readlink loop
    # (inside the container and on the host)

Which inodes differ? Is any of them the same? Why?

## The three questions

**1. In what sense is your unshare command conceptually equivalent to the
docker run of chapter 1?**

_(your answer)_

**2. What did you NOT get compared to a real container (images and layers,
resource limits, security)?**

_(your answer)_

**3. Why is the --fork option needed together with --pid?**

_(your answer)_
