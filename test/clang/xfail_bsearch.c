/* xfail_bsearch.c -- KNOWN GAP: standard C `bsearch` is not available under
 * zcc +cpm -compiler=llvmz80 (nor for sccz80/sdcc on the classic +cpm clib).
 *
 * WHY IT DOES NOT WORK
 *   The classic z88dk clib deliberately ships only a NON-standard 4-argument
 *   binary search, `l_bsearch(key, base, nmemb, cmp)` — no `size` parameter.
 *   It works only on arrays of 2-byte elements (pointers / ints) and computes
 *   the midpoint address with a single bit-shift (`res 0,l`) instead of the
 *   `midpoint * size` that the standard signature
 *       void *bsearch(const void *key, const void *base,
 *                     size_t nmemb, size_t size,
 *                     int (*cmp)(const void*, const void*));
 *   requires.  That multiply was intentionally avoided in 2005 because a 16-bit
 *   multiply per search slice is expensive on the Z80 (documented in
 *   libsrc/classic/stdlib/Lbsearch.asm).  So classic `+cpm` stdlib.h does not
 *   declare a standard `bsearch` at all — only the newlib target has the full
 *   5-arg version (via l_mulu_16_16x16).
 *
 * This is a CLASSIC-DESIGN gap, not an llvmz80 bug: it fails identically for
 * every compiler on `+cpm`.  Workaround: `qsort` + a hand-rolled binary search,
 * or use the newlib target.
 *
 * The .sh harness expects this TU to FAIL TO COMPILE
 * ("call to undeclared function 'bsearch'") and reports XFAIL.
 */
#include <stdlib.h>

int cmp(const void *a, const void *b) {
    return *(const int *)a - *(const int *)b;
}

int main(void) {
    int a[4] = {1, 3, 5, 7};
    int key = 5;
    /* Standard 5-arg bsearch: undeclared on classic +cpm -> compile error. */
    int *p = (int *)bsearch(&key, a, 4, sizeof(int), cmp);
    return p ? *p : -1;
}
