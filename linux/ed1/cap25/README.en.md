# Chapter 25 — Fill the Service Window

> Exercise for **Chapter 25 — Pipes and Redirection: Composing Tools** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- measure a pipe's actual capacity without assuming a fixed value;
- observe backpressure between a producer and a consumer;
- recognize a subshell created by a Bash pipeline;
- connect status 141 to SIGPIPE when pipefail is enabled.

## Prerequisites

- Linux with Bash and Python 3.
- The head command.
- No administrative privileges required.

The tests use only pipes between your own processes, wait for short bounded intervals, and close every file descriptor on exit.

## Instructions

1. Copy the answer template and run the measurement program:

       cp start/answers.md answers.md
       python3 solution/pipe-capacity.py

   The program creates a pipe, makes its write end nonblocking, and inserts bytes until the kernel returns EAGAIN. Compare the bytes actually inserted with F_GETPIPE_SZ. Do not assume that every host reports the same number.

2. In the second phase, the producer fills a fresh pipe and tries to write one more byte. The consumer waits for a measured interval, confirms that the producer is still blocked, then reads enough space. Record how long the producer remained stuck and confirm that it resumed.

3. Reproduce the variable update problem in a pipeline:

       count=0
       printf '%s\n' one two three | while IFS= read -r line; do
           count=$((count + 1))
       done
       printf 'count=%s\n' "$count"

   In Bash, the while loop on the right side of the pipe normally runs in a subshell, so its update does not return to the calling shell. Fix the data flow with process substitution:

       count=0
       while IFS= read -r line; do
           count=$((count + 1))
       done < <(printf '%s\n' one two three)
       printf 'count=%s\n' "$count"

4. Make start/broken-pipefail.sh executable and run it. Record its status:

       chmod +x start/broken-pipefail.sh
       start/broken-pipefail.sh
       printf 'status=%s\n' "$?"

   head exits after one line and closes its read end. The producer explicitly restores SIGPIPE's default disposition, tries to write again, and exits with 128 + 13, which is 141. With pipefail, that value becomes the pipeline's status; with set -e, the script stops.

5. Run the complete solution, which also captures the individual PIPESTATUS values:

       ./solution/run.sh

## Definition of "done"

- [ ] You measured capacity by actually filling a pipe until EAGAIN.
- [ ] You observed the blocked producer and its resumption after the consumer read data.
- [ ] You obtained count=0 with the pipeline and count=3 with process substitution.
- [ ] You triggered status 141 and identified the producer as the process terminated by SIGPIPE.
- [ ] Every test process and file descriptor has terminated.
