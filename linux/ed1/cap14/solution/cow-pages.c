#define _GNU_SOURCE

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>

static void fail(const char *message)
{
    perror(message);
    exit(EXIT_FAILURE);
}

static size_t parse_pages(const char *text)
{
    char *end = NULL;
    unsigned long value = strtoul(text, &end, 10);

    if (text[0] == '\0' || end == NULL || *end != '\0' || value == 0 || value > 4096) {
        fprintf(stderr, "invalid page count: %s\n", text);
        exit(EXIT_FAILURE);
    }
    return (size_t)value;
}

int main(int argc, char **argv)
{
    size_t pages = argc == 2 ? parse_pages(argv[1]) : 16;
    size_t page_size = (size_t)sysconf(_SC_PAGESIZE);
    size_t length = pages * page_size;
    size_t results_length = pages * sizeof(long);
    unsigned char *area = mmap(NULL, length, PROT_READ | PROT_WRITE,
                               MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    long *deltas = mmap(NULL, results_length, PROT_READ | PROT_WRITE,
                        MAP_SHARED | MAP_ANONYMOUS, -1, 0);
    struct rusage usage;
    long cumulative = 0;
    pid_t child;
    size_t index;
    int status;

    if (setvbuf(stdout, NULL, _IONBF, 0) != 0)
        fail("setvbuf");
    if (area == MAP_FAILED)
        fail("mmap");
    if (deltas == MAP_FAILED)
        fail("mmap");
    for (index = 0; index < pages; ++index) {
        area[index * page_size] = 1;
        deltas[index] = 0;
    }
    if (getrusage(RUSAGE_SELF, &usage) == -1)
        fail("getrusage");

    printf("parent initialized %zu pages before fork\n", pages);
    fflush(stdout);
    child = fork();
    if (child == -1)
        fail("fork");

    if (child == 0) {
        for (index = 0; index < pages; ++index) {
            long before_faults;

            if (getrusage(RUSAGE_SELF, &usage) == -1)
                fail("getrusage");
            before_faults = usage.ru_minflt;
            area[index * page_size]++;
            if (getrusage(RUSAGE_SELF, &usage) == -1)
                fail("getrusage");
            cumulative += usage.ru_minflt - before_faults;
            deltas[index] = cumulative;
        }
        if (munmap(area, length) == -1)
            fail("munmap");
        if (munmap(deltas, results_length) == -1)
            fail("munmap");
        _exit(EXIT_SUCCESS);
    }

    if (waitpid(child, &status, 0) == -1)
        fail("waitpid");
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
        fprintf(stderr, "child failed\n");
        return EXIT_FAILURE;
    }
    printf("page  cumulative-minor-faults\n");
    for (index = 0; index < pages; ++index)
        printf("%4zu  %ld\n", index + 1, deltas[index]);
    if (munmap(area, length) == -1)
        fail("munmap");
    if (munmap(deltas, results_length) == -1)
        fail("munmap");
    return EXIT_SUCCESS;
}
