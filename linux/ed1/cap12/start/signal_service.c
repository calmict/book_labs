#define _POSIX_C_SOURCE 200809L

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>

static volatile sig_atomic_t reload_requested;
static volatile sig_atomic_t terminate_requested;

static void handle_sighup(int signal_number)
{
    /* TODO: request a reload without performing I/O in this handler. */
    (void)signal_number;
}

static void handle_sigterm(int signal_number)
{
    /* TODO: request orderly shutdown without performing I/O in this handler. */
    (void)signal_number;
}

int main(int argc, char **argv)
{
    /* TODO: install handlers, load argv[1], create argv[3] and argv[4],
       then process flags until orderly shutdown. Write events to argv[2]. */
    (void)argc;
    (void)argv;
    (void)reload_requested;
    (void)terminate_requested;
    (void)handle_sighup;
    (void)handle_sigterm;
    return EXIT_FAILURE;
}
