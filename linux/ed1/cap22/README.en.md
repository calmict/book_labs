# Chapter 22 — Two Groups, One Directory

> Exercise for **Chapter 22 — ACLs and Extended Permissions** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Intermediate

## Objectives

By the end of this lab you will be able to:

- grant different rights to two groups on the same directory;
- define default ACLs that propagate to newly created content;
- interpret the ACL mask and the effect of chmod on extended ACLs;
- verify which copy methods preserve ACLs.

## Prerequisites

- A Linux host with a filesystem that supports POSIX ACLs.
- The setfacl and getfacl commands, provided by the acl package.
- Two groups that already exist on the system. For the automated demonstration, prefer two groups listed by id -Gn.

Check the requirements before starting:

    command -v setfacl getfacl
    findmnt -T . -no FSTYPE,OPTIONS
    getent group | head

All tests take place in a scratch directory inside the exercise. Do not create users or groups on the host.

## Instructions

1. Copy the answer template and choose two existing groups, one for writing and one for read-only access:

       cp start/answers.md answers.md
       id -Gn
       getent group

2. Create a scratch directory and initially restrict it to its owner:

       mkdir -p labcap22-scratch/project
       chmod 700 labcap22-scratch/project

3. Use setfacl to grant rwx to the writing group and r-x to the reading group. Add equivalent default ACLs to the directory. Keep the owning group and other users at ---.

4. Create a plan.txt file and a docs subdirectory inside the directory. Use getfacl to prove that both inherited the expected entries. Explain why the directory's default ACL becomes an access ACL on newly created objects.

5. Run a careless chmod on plan.txt:

       chmod 640 labcap22-scratch/project/plan.txt

   Inspect the file again. Find the mask, the effective annotations, and the reason the named groups no longer have the expected rights. Restore the mask with setfacl without recreating every entry.

6. Add an unmistakable named ACL to the file, then make three copies:

   - one with cp -a;
   - one with cp --no-preserve=mode;
   - one by redirecting cat's output.

   Compare getfacl output for all four files and record which copies retain the named entries. Redirection creates a new inode according to the umask and any default ACL on the destination directory; it does not clone the source file's metadata.

7. Compare your findings with solution/answers.md or run the automated demonstration:

       ./solution/run.sh

8. Remove answers.md and the scratch directory when finished.

## Definition of "done"

- [ ] The directory grants different rights to two groups beyond the traditional nine mode bits.
- [ ] A new file and subdirectory inherit the default ACL.
- [ ] You observed chmod changing the mask and restored access with setfacl.
- [ ] You compared one copy that preserves ACLs with two copies that do not clone the named ACL.
- [ ] You completed answers.md and removed the scratch directory.
