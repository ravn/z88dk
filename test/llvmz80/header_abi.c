/* Tests z88dk classic ABI integration under llvmz80 (__smallc default).
 *
 * Covers the stdlib entries PR #90 wires up through the classic clib
 * (strcpy/strcmp/memcpy/memcmp via ZPROTO __z88dk_callee thunks; qsort
 * and bsearch via __asm__("qsort")/__asm__("bsearch") routed to the
 * sccz80 bare-name entry points that match __smallc push order).
 *
 * Exit codes are distinct per probe so an ntvcm failure identifies the
 * failing entry exactly. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int abs_fastcall(int value) __z88dk_fastcall;

static int cmp_int(const void *a, const void *b)
{
    int ia = *(const int *)a;
    int ib = *(const int *)b;
    return ia - ib;
}

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

        /* strcpy: ZPROTO __z88dk_callee classic entry, verifies PR #90
         * compiler.h branch and __smallc push matches callee convention. */
        char dst[8];
        if (strcpy(dst, "abcd") != dst)
            return 10;
        if (dst[0] != 'a' || dst[3] != 'd' || dst[4] != 0)
            return 11;

        /* strcmp: two-arg classic entry via ZPROTO. */
        if (strcmp("foo", "foo") != 0)
            return 12;
        if (strcmp("foo", "fop") >= 0)
            return 13;
        if (strcmp("fop", "foo") <= 0)
            return 14;

        /* memcpy: three-arg via ZPROTO; exercises builtin -> classic. */
        char src[8] = {1,2,3,4,5,6,7,8};
        char mdst[8] = {0};
        if (memcpy(mdst, src, 5) != mdst)
            return 15;
        if (mdst[0] != 1 || mdst[4] != 5 || mdst[5] != 0)
            return 16;

        /* memcmp: three-arg via ZPROTO. */
        if (memcmp(mdst, src, 5) != 0)
            return 17;
        mdst[2] = 99;
        if (memcmp(mdst, src, 5) == 0)
            return 18;

        /* qsort: __asm__("qsort") routes to sccz80 bare entry so the
         * comparator left-to-right push matches __smallc. */
        int arr[5] = {5, 2, 4, 1, 3};
        qsort(arr, 5, sizeof(int), cmp_int);
        if (arr[0] != 1 || arr[1] != 2 || arr[2] != 3 ||
            arr[3] != 4 || arr[4] != 5)
            return 20;

        /* bsearch: same __asm__-routing as qsort. */
        int key = 3;
        int *found = bsearch(&key, arr, 5, sizeof(int), cmp_int);
        if (!found || *found != 3)
            return 21;
        int missing = 99;
        if (bsearch(&missing, arr, 5, sizeof(int), cmp_int) != NULL)
            return 22;
    }
    printf("ALL PASS\n");
    printf("X");
    return 0;
}
