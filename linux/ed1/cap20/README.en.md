# Chapter 20 — The Number Behind the Name

> Exercise for **Chapter 20 — Users, Groups, and Identity** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- distinguish an account name from its numeric UID;
- predict how renumbering affects the ownership name displayed for files;
- diagnose permission failures on a volume shared by environments with different UID maps;
- follow a PAM chain and identify the auth, account, password, and session groups.

## Prerequisites

- A Linux host with Bash and a working Docker installation.
- A rockylinux:9 image available locally or ready to download.
- Read-only access to /etc/pam.d on the host.
- No host account is created or changed: every useradd and usermod command must remain inside containers started with --rm.

## Instructions

1. Start an ephemeral container and create labcap20alice with UID 21001. Outside that account's home, create a file owned by 21001 and use stat to inspect both the number and its resolved name.

       docker run --rm -it --name labcap20-identity rockylinux:9 bash
       useradd --uid 21001 --no-create-home labcap20alice
       touch /tmp/labcap20-owned
       chown 21001:21001 /tmp/labcap20-owned
       stat -c 'uid=%u owner=%U' /tmp/labcap20-owned

2. Change labcap20alice to UID 21002. Verify that the inode still stores 21001 and that the old number no longer resolves to the former name. Then assign 21001 to labcap20replacement: without changing the file, stat now displays the new name as its owner. Explain that name resolution changed, not the number stored in the inode.

       usermod --uid 21002 labcap20alice
       stat -c 'uid=%u owner=%U' /tmp/labcap20-owned
       useradd --uid 21001 --no-create-home labcap20replacement
       stat -c 'uid=%u owner=%U' /tmp/labcap20-owned

3. Create a labcap20-shared directory inside the exercise. Mount it in a first container, where labcap20shared has UID 23001, and create a mode 0600 file as that user. Exit the container and let --rm remove it.

4. Mount the same directory in a second ephemeral container, but assign UID 24001 to labcap20shared. Verify that matching names are not enough: the file retains UID 23001 and user 24001 cannot read it. Align a UID map only after identifying the number that must be shared.

5. On the host, read /etc/pam.d/login without modifying it. Follow include and substack directives to existing files under /etc/pam.d and classify rules into the four functional groups:

       awk '$1 ~ /^-?(auth|account|password|session)$/ {print}' /etc/pam.d/login

   auth determines how authentication works, account whether the account may be used, password how credentials are changed, and session what runs when a session opens or closes. Rule order and each control value are part of the chain.

6. Exit every container shell and verify that no labcap20 container remains. Record output and explanations in answers.md, or run the automated solution:

       ./solution/run.sh

## Definition of "done"

- [ ] useradd and usermod ran only inside an ephemeral container.
- [ ] You observed UID 21001 remain in the inode while its displayed owner name disappeared and then changed.
- [ ] The shared volume reproduces a read denial between UIDs 23001 and 24001 despite matching user names.
- [ ] You identified auth, account, password, and session in the host's PAM chain.
- [ ] PAM files were not modified, and all labcap20 containers and test data were removed.

