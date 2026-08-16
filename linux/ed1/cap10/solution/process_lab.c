#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

static volatile sig_atomic_t reap_requested;

static void fail(const char *message)
{
    perror(message);
    exit(EXIT_FAILURE);
}

static void record_pid(const char *state_dir, const char *name, pid_t pid)
{
    char path[PATH_MAX];
    char value[64];
    int fd;
    int length;

    if (snprintf(path, sizeof(path), "%s/%s", state_dir, name) >= (int)sizeof(path)) {
        errno = ENAMETOOLONG;
        fail("state path");
    }

    fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (fd == -1)
        fail("open state file");

    length = snprintf(value, sizeof(value), "%ld\n", (long)pid);
    if (write(fd, value, (size_t)length) != length) {
        int saved_errno = errno;
        close(fd);
        errno = saved_errno;
        fail("write state file");
    }
    if (close(fd) == -1)
        fail("close state file");
}

static void mark_ready(const char *state_dir, const char *name)
{
    record_pid(state_dir, name, getpid());
}

static int run_fork_demo(const char *state_dir)
{
    pid_t child;
    int status;

    record_pid(state_dir, "parent.pid", getpid());
    child = fork();
    if (child == -1)
        fail("fork");
    if (child == 0) {
        record_pid(state_dir, "child.pid", getpid());
        sleep(3);
        _exit(EXIT_SUCCESS);
    }

    if (waitpid(child, &status, 0) == -1)
        fail("waitpid");
    return WIFEXITED(status) && WEXITSTATUS(status) == EXIT_SUCCESS
        ? EXIT_SUCCESS : EXIT_FAILURE;
}

static int run_exec_demo(const char *state_dir)
{
    record_pid(state_dir, "exec-before.pid", getpid());
    execlp("sleep", "sleep", "3", (char *)NULL);
    fail("exec sleep");
    return EXIT_FAILURE;
}

static void request_reap(int signal_number)
{
    (void)signal_number;
    reap_requested = 1;
}

static void alarm_exit(int signal_number)
{
    (void)signal_number;
    _exit(124);
}

static int run_zombie_demo(const char *state_dir)
{
    struct sigaction action = {0};
    struct sigaction alarm_action = {0};
    pid_t child;
    int status;

    action.sa_handler = request_reap;
    sigemptyset(&action.sa_mask);
    if (sigaction(SIGUSR1, &action, NULL) == -1)
        fail("sigaction SIGUSR1");

    alarm_action.sa_handler = alarm_exit;
    sigemptyset(&alarm_action.sa_mask);
    if (sigaction(SIGALRM, &alarm_action, NULL) == -1)
        fail("sigaction SIGALRM");

    record_pid(state_dir, "zombie-parent.pid", getpid());
    child = fork();
    if (child == -1)
        fail("fork");
    if (child == 0) {
        record_pid(state_dir, "zombie-child.pid", getpid());
        _exit(42);
    }

    alarm(15);
    while (!reap_requested)
        pause();
    alarm(0);

    if (waitpid(child, &status, 0) == -1)
        fail("waitpid");
    mark_ready(state_dir, "reaped");
    sleep(2);
    return WIFEXITED(status) && WEXITSTATUS(status) == 42
        ? EXIT_SUCCESS : EXIT_FAILURE;
}

int main(int argc, char **argv)
{
    if (argc != 3) {
        fprintf(stderr, "usage: %s {fork|exec|zombie} STATE_DIR\n", argv[0]);
        return EXIT_FAILURE;
    }
    if (mkdir(argv[2], 0700) == -1 && errno != EEXIST)
        fail("mkdir state directory");

    if (strcmp(argv[1], "fork") == 0)
        return run_fork_demo(argv[2]);
    if (strcmp(argv[1], "exec") == 0)
        return run_exec_demo(argv[2]);
    if (strcmp(argv[1], "zombie") == 0)
        return run_zombie_demo(argv[2]);

    fprintf(stderr, "unknown mode: %s\n", argv[1]);
    return EXIT_FAILURE;
}
