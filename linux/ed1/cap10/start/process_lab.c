#define _POSIX_C_SOURCE 200809L

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

static int run_fork_demo(const char *state_dir)
{
    /* TODO: create a child, record both PIDs, and reap the child. */
    (void)state_dir;
    return EXIT_FAILURE;
}

static int run_exec_demo(const char *state_dir)
{
    /* TODO: record getpid(), then replace this program with sleep. */
    (void)state_dir;
    return EXIT_FAILURE;
}

static int run_zombie_demo(const char *state_dir)
{
    /* TODO: leave a terminated child unreaped until the parent gets SIGUSR1. */
    (void)state_dir;
    return EXIT_FAILURE;
}

int main(int argc, char **argv)
{
    if (argc != 3) {
        fprintf(stderr, "usage: %s {fork|exec|zombie} STATE_DIR\n", argv[0]);
        return EXIT_FAILURE;
    }

    if (strcmp(argv[1], "fork") == 0)
        return run_fork_demo(argv[2]);
    if (strcmp(argv[1], "exec") == 0)
        return run_exec_demo(argv[2]);
    if (strcmp(argv[1], "zombie") == 0)
        return run_zombie_demo(argv[2]);

    fprintf(stderr, "unknown mode: %s\n", argv[1]);
    return EXIT_FAILURE;
}
