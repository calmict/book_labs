#include <errno.h>
#include <netinet/in.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

int main(void) {
    int descriptor;

    printf("uid=%ld euid=%ld\n", (long)getuid(), (long)geteuid());
    descriptor = socket(AF_INET, SOCK_RAW, IPPROTO_ICMP);
    if (descriptor == -1) {
        fprintf(stderr, "raw socket: %s\n", strerror(errno));
        return 1;
    }
    puts("raw socket: opened");
    close(descriptor);
    return 0;
}

