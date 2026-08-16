#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <unistd.h>

static void fail(const char *message)
{
    perror(message);
    exit(EXIT_FAILURE);
}

static size_t parse_mebibytes(const char *text)
{
    char *end = NULL;
    unsigned long value = strtoul(text, &end, 10);

    if (text[0] == '\0' || end == NULL || *end != '\0' || value == 0 || value > 1024) {
        fprintf(stderr, "invalid size in MiB: %s\n", text);
        exit(EXIT_FAILURE);
    }
    return (size_t)value * 1024U * 1024U;
}

static void prepare_file(const char *path, size_t length)
{
    int fd = open(path, O_CREAT | O_TRUNC | O_RDWR, 0600);
    long page_size = sysconf(_SC_PAGESIZE);
    unsigned char *mapping;
    size_t offset;

    if (fd == -1)
        fail("open");
    if (ftruncate(fd, (off_t)length) == -1)
        fail("ftruncate");
    mapping = mmap(NULL, length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (mapping == MAP_FAILED)
        fail("mmap");

    for (offset = 0; offset < length; offset += (size_t)page_size)
        mapping[offset] = (unsigned char)(offset / (size_t)page_size);

    if (msync(mapping, length, MS_SYNC) == -1)
        fail("msync");
    if (munmap(mapping, length) == -1)
        fail("munmap");
    if (fsync(fd) == -1)
        fail("fsync");
    {
        int advice_error = posix_fadvise(fd, 0, (off_t)length, POSIX_FADV_DONTNEED);
        if (advice_error != 0) {
            errno = advice_error;
            fail("posix_fadvise");
        }
    }
    if (close(fd) == -1)
        fail("close");

    printf("prepared %zu MiB in %s and requested page-cache eviction\n",
           length / 1024U / 1024U, path);
}

static void read_file(const char *path)
{
    int fd = open(path, O_RDONLY);
    struct stat status;
    struct rusage before;
    struct rusage after;
    long page_size = sysconf(_SC_PAGESIZE);
    unsigned char *mapping;
    volatile uint64_t checksum = 0;
    size_t offset;

    if (fd == -1)
        fail("open");
    if (fstat(fd, &status) == -1)
        fail("fstat");
    if (status.st_size <= 0) {
        fprintf(stderr, "input file is empty\n");
        exit(EXIT_FAILURE);
    }
    mapping = mmap(NULL, (size_t)status.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
    if (mapping == MAP_FAILED)
        fail("mmap");
    if (getrusage(RUSAGE_SELF, &before) == -1)
        fail("getrusage");

    for (offset = 0; offset < (size_t)status.st_size; offset += (size_t)page_size)
        checksum += mapping[offset];

    if (getrusage(RUSAGE_SELF, &after) == -1)
        fail("getrusage");
    printf("pages touched: %zu\n", ((size_t)status.st_size + (size_t)page_size - 1) / (size_t)page_size);
    printf("minor faults during mapped read: %ld\n", after.ru_minflt - before.ru_minflt);
    printf("major faults during mapped read: %ld\n", after.ru_majflt - before.ru_majflt);
    printf("checksum: %llu\n", (unsigned long long)checksum);

    if (munmap(mapping, (size_t)status.st_size) == -1)
        fail("munmap");
    if (close(fd) == -1)
        fail("close");
}

int main(int argc, char **argv)
{
    if (argc == 4 && strcmp(argv[1], "prepare") == 0) {
        prepare_file(argv[2], parse_mebibytes(argv[3]));
        return EXIT_SUCCESS;
    }
    if (argc == 3 && strcmp(argv[1], "read") == 0) {
        read_file(argv[2]);
        return EXIT_SUCCESS;
    }

    fprintf(stderr, "usage: %s prepare FILE MIB | read FILE\n", argv[0]);
    return EXIT_FAILURE;
}
