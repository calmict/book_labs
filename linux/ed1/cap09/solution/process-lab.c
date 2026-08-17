#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

static volatile sig_atomic_t requested = 0;

static void handle_signal(int signal_number)
{
    (void)signal_number;
    requested = 1;
}

static char *join_path(const char *directory, const char *name)
{
    size_t directory_length = strlen(directory);
    size_t name_length = strlen(name);
    char *result = malloc(directory_length + name_length + 2U);

    if (result == NULL) {
        perror("malloc");
        exit(EXIT_FAILURE);
    }
    memcpy(result, directory, directory_length);
    result[directory_length] = '/';
    memcpy(result + directory_length + 1U, name, name_length + 1U);
    return result;
}

static void write_text_file(const char *path, const char *text)
{
    int descriptor = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    size_t length = strlen(text);
    ssize_t written;

    if (descriptor == -1) {
        perror(path);
        exit(EXIT_FAILURE);
    }
    written = write(descriptor, text, length);
    if (written < 0 || (size_t)written != length) {
        perror("write");
        close(descriptor);
        exit(EXIT_FAILURE);
    }
    if (close(descriptor) == -1) {
        perror("close");
        exit(EXIT_FAILURE);
    }
}

static void write_pid_file(const char *path, pid_t pid)
{
    char text[64];
    int length = snprintf(text, sizeof(text), "%ld\n", (long)pid);

    if (length < 0 || (size_t)length >= sizeof(text)) {
        fputs("Could not format PID\n", stderr);
        exit(EXIT_FAILURE);
    }
    write_text_file(path, text);
}

static void install_handler(int signal_number)
{
    struct sigaction action;

    memset(&action, 0, sizeof(action));
    action.sa_handler = handle_signal;
    sigemptyset(&action.sa_mask);
    if (sigaction(signal_number, &action, NULL) == -1) {
        perror("sigaction");
        exit(EXIT_FAILURE);
    }
}

static int run_inspect(const char *directory)
{
    const size_t allocation_size = 8U * 1024U * 1024U;
    char *open_file_path = join_path(directory, "labcap09-open-file.txt");
    char *ready_path = join_path(directory, "inspect-ready");
    int open_file = open(open_file_path, O_RDWR | O_CREAT | O_TRUNC, 0600);
    unsigned char *memory;
    long page_size;
    size_t offset;

    if (open_file == -1) {
        perror(open_file_path);
        return EXIT_FAILURE;
    }
    if (write(open_file, "held open by labcap09\n", 22U) != 22) {
        perror("write");
        return EXIT_FAILURE;
    }
    memory = malloc(allocation_size);
    if (memory == NULL) {
        perror("malloc");
        return EXIT_FAILURE;
    }
    page_size = sysconf(_SC_PAGESIZE);
    if (page_size <= 0) {
        fputs("Could not determine page size\n", stderr);
        return EXIT_FAILURE;
    }
    for (offset = 0; offset < allocation_size; offset += (size_t)page_size) {
        memory[offset] = (unsigned char)(offset / (size_t)page_size);
    }

    install_handler(SIGTERM);
    install_handler(SIGINT);
    write_pid_file(ready_path, getpid());
    while (!requested) {
        pause();
    }

    free(memory);
    free(ready_path);
    free(open_file_path);
    if (close(open_file) == -1) {
        perror("close");
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}

static int run_zombie(const char *directory)
{
    char *parent_path = join_path(directory, "zombie-parent.pid");
    char *child_path = join_path(directory, "zombie-child.pid");
    char *reaped_path = join_path(directory, "zombie-reaped");
    pid_t child;
    int child_status;

    install_handler(SIGUSR1);
    install_handler(SIGTERM);
    child = fork();
    if (child == -1) {
        perror("fork");
        return EXIT_FAILURE;
    }
    if (child == 0) {
        _exit(23);
    }

    write_pid_file(parent_path, getpid());
    write_pid_file(child_path, child);
    while (!requested) {
        pause();
    }
    if (waitpid(child, &child_status, 0) != child) {
        perror("waitpid");
        return EXIT_FAILURE;
    }
    if (!WIFEXITED(child_status) || WEXITSTATUS(child_status) != 23) {
        fputs("Unexpected child exit status\n", stderr);
        return EXIT_FAILURE;
    }
    write_text_file(reaped_path, "reaped\n");
    free(reaped_path);
    free(child_path);
    free(parent_path);
    return EXIT_SUCCESS;
}

static int run_fifo(const char *fifo_path, const char *pid_path)
{
    int descriptor;

    write_pid_file(pid_path, getpid());
    descriptor = open(fifo_path, O_RDONLY);
    if (descriptor == -1) {
        perror("open FIFO");
        return EXIT_FAILURE;
    }
    close(descriptor);
    return EXIT_SUCCESS;
}

int main(int argc, char **argv)
{
    if (argc == 3 && strcmp(argv[1], "inspect") == 0) {
        return run_inspect(argv[2]);
    }
    if (argc == 3 && strcmp(argv[1], "zombie") == 0) {
        return run_zombie(argv[2]);
    }
    if (argc == 4 && strcmp(argv[1], "fifo") == 0) {
        return run_fifo(argv[2], argv[3]);
    }
    fprintf(stderr, "Usage: %s inspect DIRECTORY | zombie DIRECTORY | fifo FIFO PIDFILE\n", argv[0]);
    return EXIT_FAILURE;
}
