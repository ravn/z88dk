/* Classic FILE* regression for ravn/z88dk#22.
 * Restored from ravn-main:test/clang/issue22_stdio_abi.c.
 * A.DAT deliberately remains for the harness to remove with its working dir.
 */
#include <stdio.h>

int main(void)
{
    FILE *f = fopen("A.DAT", "wb");
    if (!f) {
        puts("FAIL: fopen wb");
        return 1;
    }
    int r = fputs("hello\n", f);
    printf("fputs=%d %s\n", r, r > 0 ? "OK" : "BAD");
    fflush(stdout);
    fclose(f);

    f = fopen("A.DAT", "rb");
    if (!f) {
        puts("FAIL: fopen rb");
        return 1;
    }
    char buf[16];
    char *g = fgets(buf, sizeof buf, f);
    int fgets_ok = (g != 0) && (buf[0] == 'h') && (buf[4] == 'o');
    printf("fgets=%s %s\n", fgets_ok ? "hello" : "BAD", fgets_ok ? "OK" : "BAD");
    fflush(stdout);
    fclose(f);

    f = fopen("A.DAT", "rb");
    if (!f) {
        puts("FAIL: fopen ungetc");
        return 1;
    }
    int a = fgetc(f);
    int u = ungetc(a, f);
    int b = fgetc(f);
    int ungetc_ok = (u == a) && (b == a);
    printf("ungetc=%d,%c,%c %s\n", u, a, b, ungetc_ok ? "OK" : "BAD");
    fflush(stdout);
    fclose(f);

    f = fopen("A.DAT", "rb");
    if (!f) {
        puts("FAIL: fopen fgetpos");
        return 1;
    }
    fgetc(f);
    fgetc(f);
    fpos_t pos;
    int pr = fgetpos(f, &pos);
    int fgetpos_ok = (pr == 0) && ((long)pos == 2);
    printf("fgetpos=%d,%ld %s\n", pr, (long)pos, fgetpos_ok ? "OK" : "BAD");
    fflush(stdout);
    fclose(f);

    puts("DONE");
    return 0;
}
