# Chapter 18 — The Name Is Not the File

> Exercise for **Chapter 18 — Inodes, Links, and Filesystem Structure** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- distinguish a directory entry from the inode it points to;
- compare hard links and symbolic links when a name is removed;
- recognize inode exhaustion even when data space remains available;
- publish a complete file through an atomic rename.

## Prerequisites

- A Linux host with Bash, coreutils, util-linux, and e2fsprogs.
- Administrative permission for losetup, mount, and umount only during the inode-exhaustion test.
- At least 20 MiB free in the exercise directory.
- No important data in solution/labcap18-work: the script recreates and removes it.

## Instructions

1. Create a file, inspect it with stat, and make a hard link. Compare the inode number and link count before and after creating the link. Remove one name and verify that the content and inode remain accessible through the other one.

       printf 'shared content\n' > original.txt
       stat -c '%i %h %n' original.txt
       ln original.txt hard-link.txt
       stat -c '%i %h %n' original.txt hard-link.txt
       rm original.txt
       stat -c '%i %h %n' hard-link.txt

2. Create a symbolic link to a file, remove the target, and compare the results of test -L and test -e. Explain why the link still exists but no longer resolves to a file.

       printf 'target\n' > target.txt
       ln -s target.txt symbolic-link.txt
       rm target.txt
       test -L symbolic-link.txt
       test -e symbolic-link.txt

3. Create only a 16 MiB image with very few inodes, attach it to a loop device, and mount it in the lab directory. Do not use a real partition or device.

       dd if=/dev/zero of=labcap18.img bs=1M count=16
       mkfs.ext4 -N 128 labcap18.img
       sudo losetup --find --show labcap18.img
       sudo mount LOOP_DEVICE labcap18-mnt

4. Create empty files on the mounted filesystem until the operation fails. Compare df -h and df -i: data space must remain while the available inode count reaches zero. Unmount, detach the loop device, and remove the image and mount point even if an error occurs.

5. Implement atomic publication: write the new content to a temporary file in the same directory as the final file, close it, and replace the final name with mv. Run a reader at the same time and verify that it sees only the old or new version, never a missing or partial file.

6. Record the essential observations and output in answers.md. You can run the complete solution with administrative privileges:

       sudo ./solution/run.sh

## Definition of "done"

- [ ] Both hard links have the same inode and the count rises to 2, then returns to 1 after one name is removed.
- [ ] The broken symbolic link is recognized as a link but not as a path to an existing file.
- [ ] Exhaustion occurs only on labcap18.img, and df shows no free inodes while data space remains.
- [ ] The atomic-rename reader observes no missing or partial state.
- [ ] The loop device, mount, image, and temporary files have been removed at the end.

