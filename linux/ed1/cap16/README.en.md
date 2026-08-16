# Chapter 16 — Work with Numbers, Not Names

> Exercise for **Chapter 16 — Everything Is a File: Descriptors and I/O** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- inspect a process's descriptor table across open and close operations;
- verify that redirection changes the object assigned to a descriptor number;
- identify an unlinked file that is still open;
- connect the last descriptor's close operation with reclamation of the occupied space.

## Prerequisites

- A Linux host with Bash 4 or later and Python 3.
- lsof installed.
- Read access to /proc for your own processes.
- About 20 MiB of free space in /tmp.

## Instructions

Run the complete automated demonstration with:

    solution/run.sh

1. The fd-lifecycle.py program pauses in three states: before open, after open, and after close. At each state, list /proc/PID/fd and note which new number appears and which file it refers to. After close, verify that the same number no longer exists.

2. In a subshell, save stdout as descriptor 3 and replace descriptor 1 with a file:

       exec 3>&1
       exec 1>output.txt

   Inspect the /proc/PID/fd/1 link. The command does not rename stdout: it assigns a new open file description to number 1. Diagnostic output can still be displayed through number 3.

3. A second process keeps a 16 MiB file open. Unlink its name while the descriptor remains open and locate the process with:

       lsof +L1 -p PID

   Record NAME, SIZE/OFF, and NLINK. NAME ends in deleted and NLINK is zero: the name is no longer reachable, but the contents occupy space while the process retains its reference.

4. Let the process close its descriptor and run lsof again. The entry disappears and the space can be reclaimed. Record your observations and explanations in start/observations.md.

All files are created in a private temporary directory. The script installs an exit handler that terminates helpers and removes the directory even after an error.

## Definition of "done"

- [ ] You compared the descriptor table before open, after open, and after close.
- [ ] You identified the descriptor number that was added and later removed.
- [ ] You verified that descriptor 1 refers to the file after redirection.
- [ ] You found the open unlinked file with lsof and observed an NLINK value of zero.
- [ ] You verified that the entry disappears after close.
- [ ] No lab process or temporary file remains at the end.
