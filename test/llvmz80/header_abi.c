/* Tests z88dk classic ABI attributes and heap under llvmz80 (__smallc default).
 *
 * ROOT CAUSE OF LIMITATIONS: z88dk classic library string/memory functions
 * (strcpy, strcmp, memcmp, realloc, qsort, bsearch, longjmp, wcmatch, ...) are
 * compiled with sccz80 left-to-right argument pushing.  llvmz80's __smallc uses
 * right-to-left (cdecl order).  Two-argument sccz80 library functions receive
 * their arguments swapped, producing wrong results or crashes.
 *
 * Functions that work: single-argument functions (malloc, free, puts, abs,
 * strlen), variadic functions using SP-relative stack access (printf, snprintf),
 * and __z88dk_fastcall functions (argument in HL register, convention-agnostic).
 *
 * This is a z88dk classic library portability issue: the library needs to be
 * recompiled with right-to-left argument pushing, or llvmz80's __smallc
 * must be changed to match sccz80. */
#include <stdio.h>
#include <stdlib.h>
#pragma printf = "%d"

extern int abs_fastcall(int value) __z88dk_fastcall;

int main(void)
{
    for (int i = 0; i < 100; ++i) {
        /* malloc/free: single-argument, works */
        char *buf = malloc(16);
        if (!buf)
            return 3;
        buf[0] = 'a'; buf[1] = 'b'; buf[2] = 'c'; buf[3] = 0;
        if (buf[0] != 'a' || buf[2] != 'c')
            return 4;
        free(buf);

        /* abs_fastcall: __z88dk_fastcall passes arg in HL, works */
        if (abs_fastcall(-42) != 42)
            return 5;

        /* snprintf: variadic with SP-relative access, works */
        char out[16];
        if (snprintf(out, sizeof out, "%d", 1234) != 4)
            return 6;
        if (out[0] != '1' || out[3] != '4')
            return 7;
    }
    printf("ALL PASS\n");
    printf("X");
    return 0;
}
