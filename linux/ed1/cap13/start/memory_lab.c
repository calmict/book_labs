#define _GNU_SOURCE

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

#define FIXED_ADDRESS ((void *)0x500000000000ULL)

static volatile sig_atomic_t change_requested;
static volatile sig_atomic_t snapshot_requested;
static volatile sig_atomic_t terminate_requested;

int main(int argc, char **argv)
{
    /* TODO: map one page at FIXED_ADDRESS with MAP_FIXED_NOREPLACE.
       Store argv[1], record PID, address, and value under argv[2], then:
       - change only this private page after SIGUSR1;
       - write a snapshot after SIGUSR2;
       - unmap and exit after SIGTERM.
       Signal handlers must only set the flags declared above. */
    (void)argc;
    (void)argv;
    (void)change_requested;
    (void)snapshot_requested;
    (void)terminate_requested;
    return EXIT_FAILURE;
}
