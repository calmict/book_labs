# Chapter 13 — Model Observations

## Same virtual address, independent contents

Both processes map a page at 0x500000000000, yet alpha reads alpha and beta reads beta. After SIGUSR1 changes only alpha, fresh snapshots show alpha-changed and beta. A virtual address is interpreted through the current process's page tables, so equal address numbers need not resolve to the same physical page.

## Memory map

The executable and dynamic libraries have separate read-only, executable, and writable private segments. Heap, stack, and the fixed anonymous page are readable, writable, and private. vvar is kernel-provided read-only data, while vdso includes executable kernel-provided code. Private mappings carry p in the fourth permission position; a genuinely shared mapping would carry s.

## RSS and PSS

RSS counts every resident mapped page at full size for each process. PSS counts private pages fully but divides shared executable and library pages among the processes mapping them. Each PSS is therefore lower than its RSS in this experiment, and total PSS better represents the combined physical-memory share than simply adding both RSS values.
