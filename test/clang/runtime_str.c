/* Runtime regression test for the ravn/llvm-z80 clang string/mem bridges in
 * z88dk (libsrc/string/c/sccz80/{strcpy,strcmp,strcat,strchr,strncpy,memcmp,
 * memchr}.asm, "Clang bridge" block).
 *
 * Same root cause as runtime_mem.c: sys/proto.h declares these helpers with
 * REVERSED positional args and llvmz80 passes leading args in registers
 * (HL/DE) with any remaining arg on the stack (callee-cleaned), returning a
 * 16-bit pointer/int result in DE.  The old `defc ___X = X` aliases bound
 * these reversed-arg __X symbols to the sccz80 STACK-ABI workers, reading
 * garbage -> hang/garbage.  The bridges were rewritten to convert the
 * register ABI to the asm_X workers (result HL -> DE via ex de,hl).
 *
 * This exercises all seven and prints a single line the .sh harness matches.
 */
#include <string.h>
#include <stdio.h>

int main(void) {
    /* strcpy + returned pointer */
    char b[24];
    char *rcp = strcpy(b, "Hello");

    /* strcat + returned pointer */
    char *rct = strcat(b, "!");

    /* strncpy: copy 3 of "XYZ" into a dotted buffer, no NUL past n */
    char nb[8];
    memset(nb, '.', 7);
    nb[7] = 0;
    char src[4] = {'X', 'Y', 'Z', 0};
    char *rnc = strncpy(nb, src, 3);

    /* strcmp: eq / lt / gt */
    int ceq = strcmp("ab", "ab");
    int clt = strcmp("ab", "ac") < 0;
    int cgt = strcmp("ac", "ab") > 0;

    /* strchr: index of 'l' in "hello" (2) */
    char *pc = strchr("hello", 'l');

    /* memchr: index of 'l' in "hello" over 5 bytes (2) */
    void *pm = memchr("hello", 'l', 5);

    /* memcmp: "abcd" < "abce" -> 1 */
    int mlt = memcmp("abcd", "abce", 4) < 0;

    printf("str [%s] %d %d [%s] %d %d%d%d %d %d %d\n",
           b, (int)(rcp == b), (int)(rct == b),
           nb, (int)(rnc == nb),
           ceq, clt, cgt,
           (int)(pc - "hello"),
           (int)((char *)pm - "hello"),
           mlt);
    return 0;
}
