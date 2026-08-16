# Chapter 1 — Traces of History on Your Machine

> Exercise for **Chapter 1 — From Unix to Linux: The History That Explains the Present** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- read a kernel release and distinguish its base version from the distribution suffix;
- trace a command back to its package and the license declared in local package metadata;
- recognize a merged-/usr system and explain why /bin points to /usr/bin.

## Prerequisites

- A Linux system with Bash and terminal access.
- The uname, ls, and readlink commands.
- Either an RPM or dpkg package manager with its local database available.
- No administrator privileges, containers, or network access: every operation is read-only.

## Instructions

1. Open start/history-traces.sh. Complete the kernel_trace function so that it runs uname -r, separates the leading numeric triplet from any suffix, and describes what the two parts represent. Its output must also make clear that the release string alone cannot reveal every fix that a distribution has backported.

2. Complete package_license. For each of the ls and uname commands, find the executable path and then its owning package. On an RPM-based system, use:

       rpm -qf /path/to/command
       rpm -q --qf '%{LICENSE}\n' package-name

   On Debian or Ubuntu, use dpkg-query -S to identify the package, then read the first License field in /usr/share/doc/package-name/copyright. Always print the path, package, license, and source consulted: the text shown by command --help is not enough to establish the license of the installed package.

3. Complete bin_trace. Show the result of ls -ld /bin and, when /bin is a symbolic link, print both its target and fully resolved path with readlink. Explain in the output why /bin and /usr/bin were historically separate and why modern systems merge them.

4. Remove the final INCOMPLETE message and exit 1, then check the syntax and run the script without sudo:

       bash -n start/history-traces.sh
       ./start/history-traces.sh

   Read the results from your own machine: kernel suffixes, license notation, and even whether /bin is a link can vary across distributions.

## Definition of "done"

- [ ] The script prints the release returned by uname -r, its base numeric triplet, and any distribution or build suffix.
- [ ] The output explains that the numbers identify a release line but do not, by themselves, prove whether fixes have been backported.
- [ ] The output for ls and uname includes the path, owning package, declared license, and local source consulted.
- [ ] The script shows what /bin is on the current machine and, when it is a link, where it leads.
- [ ] The explanation connects the old need for /bin before /usr was mounted with the modern merge into /usr/bin.
- [ ] The script exits successfully, needs no privileges, and makes no system changes.
