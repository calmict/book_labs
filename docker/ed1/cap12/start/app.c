#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
  if (argc == 2 && strcmp(argv[1], "uid") == 0) { printf("%d\n", getuid()); return 0; }
  if (argc == 3 && strcmp(argv[1], "probe") == 0) {
    int fd = open(argv[2], O_WRONLY | O_CREAT, 0644);
    if (fd < 0) return errno ? errno : 1;
    close(fd); return 0;
  }
  if (argc == 2 && strcmp(argv[1], "health") == 0) return access("/app/app.txt", R_OK);
  if (access("/app/app.txt", R_OK) != 0) return 1;
  for (;;) sleep(60);
}
