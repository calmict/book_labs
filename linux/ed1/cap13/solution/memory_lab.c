#define _GNU_SOURCE

#include <errno.h>
#include <limits.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#define FIXED_ADDRESS ((void *)0x500000000000ULL)

static volatile sig_atomic_t change_requested;
static volatile sig_atomic_t snapshot_requested;
static volatile sig_atomic_t terminate_requested;

static void fail(const char *message)
{
    perror(message);
    exit(EXIT_FAILURE);
}

static void handle_change(int signal_number)
{
    (void)signal_number;
    change_requested = 1;
}

static void handle_snapshot(int signal_number)
{
    (void)signal_number;
    snapshot_requested = 1;
}

static void handle_terminate(int signal_number)
{
    (void)signal_number;
    terminate_requested = 1;
}

static void install_handler(int signal_number, void (*handler)(int))
{
    struct sigaction action = {0};
    action.sa_handler = handler;
    sigemptyset(&action.sa_mask);
    if (sigaction(signal_number, &action, NULL) == -1)
        fail("sigaction");
}

static void write_state(const char *state_dir, const char *label,
                        const char *suffix, const char *value, void *address)
{
    char path[PATH_MAX];
    FILE *stream;

    if (snprintf(path, sizeof(path), "%s/%s.%s", state_dir, label, suffix)
        >= (int)sizeof(path)) {
        errno = ENAMETOOLONG;
        fail("state path");
    }
    stream = fopen(path, "w");
    if (stream == NULL)
        fail("open state file");
    if (fprintf(stream, "pid=%ld\naddress=%p\nvalue=%s\n",
                (long)getpid(), address, value) < 0)
        fail("write state file");
    if (fclose(stream) == EOF)
        fail("close state file");
}

int main(int argc, char **argv)
{
    sigset_t blocked_signals;
    sigset_t previous_mask;
    long page_size;
    char *page;

    if (argc != 3) {
        fprintf(stderr, "usage: %s LABEL STATE_DIR\n", argv[0]);
        return EXIT_FAILURE;
    }
    if (strchr(argv[1], '/') != NULL) {
        fprintf(stderr, "label must not contain a slash\n");
        return EXIT_FAILURE;
    }
    if (mkdir(argv[2], 0700) == -1 && errno != EEXIST)
        fail("mkdir state directory");

    page_size = sysconf(_SC_PAGESIZE);
    if (page_size <= 0)
        fail("sysconf page size");
    page = mmap(FIXED_ADDRESS, (size_t)page_size, PROT_READ | PROT_WRITE,
                MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED_NOREPLACE, -1, 0);
    if (page == MAP_FAILED)
        fail("mmap fixed address");
    if (page != FIXED_ADDRESS) {
        munmap(page, (size_t)page_size);
        errno = EFAULT;
        fail("unexpected mmap address");
    }
    if (snprintf(page, (size_t)page_size, "%s", argv[1]) >= page_size) {
        errno = EOVERFLOW;
        fail("label too long");
    }

    sigemptyset(&blocked_signals);
    sigaddset(&blocked_signals, SIGUSR1);
    sigaddset(&blocked_signals, SIGUSR2);
    sigaddset(&blocked_signals, SIGTERM);
    if (sigprocmask(SIG_BLOCK, &blocked_signals, &previous_mask) == -1)
        fail("block signals");
    install_handler(SIGUSR1, handle_change);
    install_handler(SIGUSR2, handle_snapshot);
    install_handler(SIGTERM, handle_terminate);

    write_state(argv[2], argv[1], "initial", page, page);
    while (!terminate_requested) {
        sigsuspend(&previous_mask);
        if (change_requested) {
            change_requested = 0;
            if (snprintf(page, (size_t)page_size, "%s-changed", argv[1])
                >= page_size) {
                errno = EOVERFLOW;
                fail("changed value too long");
            }
            write_state(argv[2], argv[1], "changed", page, page);
        }
        if (snapshot_requested) {
            snapshot_requested = 0;
            write_state(argv[2], argv[1], "snapshot", page, page);
        }
    }

    if (munmap(page, (size_t)page_size) == -1)
        fail("munmap");
    if (sigprocmask(SIG_SETMASK, &previous_mask, NULL) == -1)
        fail("restore signal mask");
    return EXIT_SUCCESS;
}
