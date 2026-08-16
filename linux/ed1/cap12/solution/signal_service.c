#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static volatile sig_atomic_t reload_requested;
static volatile sig_atomic_t terminate_requested;

static void fail(const char *message)
{
    perror(message);
    exit(EXIT_FAILURE);
}

static void append_log(const char *path, const char *message)
{
    FILE *stream = fopen(path, "a");
    if (stream == NULL)
        fail("open log");
    if (fprintf(stream, "pid=%ld %s\n", (long)getpid(), message) < 0)
        fail("write log");
    if (fclose(stream) == EOF)
        fail("close log");
}

static void create_marker(const char *path)
{
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (fd == -1)
        fail("create marker");
    if (close(fd) == -1)
        fail("close marker");
}

static void load_config(const char *config_path, const char *log_path)
{
    char line[256];
    char message[320];
    FILE *stream = fopen(config_path, "r");

    if (stream == NULL)
        fail("open configuration");
    if (fgets(line, sizeof(line), stream) == NULL) {
        if (ferror(stream))
            fail("read configuration");
        strcpy(line, "empty");
    }
    if (fclose(stream) == EOF)
        fail("close configuration");
    line[strcspn(line, "\r\n")] = '\0';
    if (snprintf(message, sizeof(message), "loaded %s", line) >= (int)sizeof(message)) {
        errno = EOVERFLOW;
        fail("format log entry");
    }
    append_log(log_path, message);
}

static void handle_sighup(int signal_number)
{
    (void)signal_number;
    reload_requested = 1;
}

static void handle_sigterm(int signal_number)
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

int main(int argc, char **argv)
{
    sigset_t blocked_signals;
    sigset_t previous_mask;

    if (argc != 5) {
        fprintf(stderr, "usage: %s CONFIG LOG WORK_MARKER READY_MARKER\n", argv[0]);
        return EXIT_FAILURE;
    }

    sigemptyset(&blocked_signals);
    sigaddset(&blocked_signals, SIGHUP);
    sigaddset(&blocked_signals, SIGTERM);
    if (sigprocmask(SIG_BLOCK, &blocked_signals, &previous_mask) == -1)
        fail("block signals");

    install_handler(SIGHUP, handle_sighup);
    install_handler(SIGTERM, handle_sigterm);
    create_marker(argv[3]);
    load_config(argv[1], argv[2]);
    create_marker(argv[4]);

    while (!terminate_requested) {
        sigsuspend(&previous_mask);
        if (reload_requested) {
            reload_requested = 0;
            load_config(argv[1], argv[2]);
        }
    }

    append_log(argv[2], "orderly shutdown");
    if (unlink(argv[3]) == -1 && errno != ENOENT)
        fail("remove work marker");
    if (sigprocmask(SIG_SETMASK, &previous_mask, NULL) == -1)
        fail("restore signal mask");
    return EXIT_SUCCESS;
}
