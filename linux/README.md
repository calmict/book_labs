# Linux — exercises

Hands-on labs for the Calm ICT book "Manuale di Linux" (metaphor: the engine
under the hood). Each chapter of the book ends with a Laboratorio box that points
here: a self-contained exercise you complete and verify. The book teaches the why;
these labs make you prove it with your hands.

Linux is the foundational volume of the series: what you build here by hand —
namespaces, cgroups, a separate root — is what the Docker volume starts from.

Every exercise has the same shape:

    ed1/capNN/
        README.it.md   - the brief (Italian)
        README.en.md   - the brief (English, mirror)
        start/         - working but incomplete files, with numbered TODOs
        solution/      - the completed, tested version
            run.sh     - end-to-end check, prints ALL CHECKS PASSED

See SETUP.md for the environment. Most labs need only a recent Linux
distribution and standard tools; the boot chapters (5-7) and the mandatory
access control chapter (23) have stricter requirements, spelled out there.

## Chapter index

| Chapter | Title | Level | Folder |
|---|---|---|---|
| 1 | Traces of History on Your Machine — From Unix to Linux: The History That Explains the Present | Foundational | [ed1/cap01](ed1/cap01/) |
| 2 | Build a Tool That Does Not Exist — The Unix Philosophy: Tools That Work Together | Foundational | [ed1/cap02](ed1/cap02/) |
| 3 | The Boundary, Seen from the Service Window — Kernel and User Space: The Line Between Two Worlds | Foundational | [ed1/cap03](ed1/cap03/) |
| 4 | Read a Machine You Do Not Know — Anatomy of an Installed System | Foundational | [ed1/cap04](ed1/cap04/) |
| 5 | Identify and Safeguard Your Boot Chain — BIOS and UEFI: Two Ways to Start a Machine | Foundational | [ed1/cap05](ed1/cap05/) |
| 6 | Enter a System Through the Service Door — The Bootloader and the Handoff | Foundational | [ed1/cap06](ed1/cap06/) |
| 7 | Open the Borrowed Toolbox — The Kernel Takes Control | Foundational | [ed1/cap07](ed1/cap07/) |
| 8 | Write a Service and Measure a Boot — PID 1: From init to systemd | Foundational | [ed1/cap08](ed1/cap08/) |
| 9 | X-Ray a Process — Anatomy of a Process | Foundational | [ed1/cap09](ed1/cap09/) |
| 10 | Duplicate, Transform, Disappear — fork, exec, wait: How a Process Is Born and Dies | Foundational | [ed1/cap10](ed1/cap10/) |
| 11 | Watch the Scheduler Decide — The Scheduler: Who Runs, and for How Long | Intermediate | [ed1/cap11](ed1/cap11/) |
| 12 | Talk to a Process That Refuses to Listen — Signals: The Kernel's Messaging System | Foundational | [ed1/cap12](ed1/cap12/) |
| 13 | Two Processes, One Address, Two Memories — Virtual Memory: Addresses That Lie | Foundational | [ed1/cap13](ed1/cap13/) |
| 14 | Trigger Faults and Watch Them Happen — Paging, Page Faults, and Swap | Foundational | [ed1/cap14](ed1/cap14/) |
| 15 | Fill Memory and See What Falls — Allocation, Cache, and the OOM Killer | Foundational | [ed1/cap15](ed1/cap15/) |
| 16 | Work with Numbers, Not Names — Everything Is a File: Descriptors and I/O | Foundational | [ed1/cap16](ed1/cap16/) |
| 17 | One Tree, Many Worlds — VFS: The Layer That Unifies Filesystems | Intermediate | [ed1/cap17](ed1/cap17/) |
| 18 | The Name Is Not the File — Inodes, Links, and Filesystem Structure | Foundational | [ed1/cap18](ed1/cap18/) |
| 19 | The Data You Think You Saved — Real Filesystems and the Block Layer | Intermediate | [ed1/cap19](ed1/cap19/) |
| 20 | The Number Behind the Name — Users, Groups, and Identity | Foundational | [ed1/cap20](ed1/cap20/) |
| 21 | Deleting a File You Cannot Read — Permissions, Setuid, and Capabilities | Foundational | [ed1/cap21](ed1/cap21/) |
| 22 | Two Groups, One Directory — ACLs and Extended Permissions | Intermediate | [ed1/cap22](ed1/cap22/) |
| 23 | Stop Root with a Policy — Mandatory Access Control and Hardening | Advanced | [ed1/cap23](ed1/cap23/) |
| 24 | The Command You Did Not Write — The Shell: What Happens Before Execution | Foundational | [ed1/cap24](ed1/cap24/) |
| 25 | Fill the Service Window — Pipes and Redirection: Composing Tools | Foundational | [ed1/cap25](ed1/cap25/) |
| 26 | Seeing What Nobody Tells You — System Calls, procfs, and sysfs: Looking Inside | Intermediate | [ed1/cap26](ed1/cap26/) |
| 27 | Following a Packet — The TCP/IP Stack Inside the Kernel | Intermediate | [ed1/cap27](ed1/cap27/) |
| 28 | Building a Network by Hand — Interfaces, Addresses, Routing, and Sockets | Intermediate | [ed1/cap28](ed1/cap28/) |
| 29 | A Minimal Firewall, with Proof of Where It Filters — nftables and the Firewall | Intermediate | [ed1/cap29](ed1/cap29/) |
| 30 | Building an Illusion — Namespaces: The Kernel's Illusions | Advanced | [ed1/cap30](ed1/cap30/) |
| 31 | Setting a Ceiling — Cgroups v2: Accounting and Limits | Advanced | [ed1/cap31](ed1/cap31/) |
| 32 | Your Container, from the First Line — A Container by Hand, Without Docker | Advanced | [ed1/cap32](ed1/cap32/) |

## Appendices

The volume closes with five reference appendices — the laboratory setup, a
reasoned CLI, a troubleshooting method, a glossary and a study roadmap. They are
part of the book, not of this repository.
