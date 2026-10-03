/* Classic fcntl regression for ravn/z88dk#23.
 * Restored from ravn-main:test/clang/issue23_fcntl_write.c.
 * WP.DAT deliberately remains for the harness to remove with its working dir.
 */
#include <stdio.h>
#include <fcntl.h>

int main(void)
{
    char buf[3] = { 'X', 'Y', 'Z' };
    int fd = open("WP.DAT", O_WRONLY | O_TRUNC | O_CREAT, 0);
    printf("open=%d\n", fd);
    fflush(stdout);
    int w = write(fd, buf, 3);
    printf("write=%d\n", w);
    fflush(stdout);
    printf("close=%d\n", close(fd));
    fflush(stdout);
    return 0;
}
