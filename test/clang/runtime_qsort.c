/* Runtime regression test for qsort with a clang/llvmz80 comparator.
 *
 * Two distinct ABI contracts:
 *   - qsort's own __smallc arguments are pushed left-to-right.
 *   - __z88dk_callback uses sdcccall(0) under llvmz80: the comparator reads
 *     left at SP+2, right at SP+4 and returns in HL, matching l_cmp_sdcc.
 *
 * Fixed mixed-sign arrays check that callback contract independently of the
 * LCG arithmetic. Both directions and duplicate elements have exact expected
 * output checked by the shell, so a broken generator cannot hide an ABI bug.
 *
 * A larger dataset (N=200 pseudo-random ints from a deterministic 16-bit LCG)
 * exercises the callback thousands of times through the quicksort recursion in
 * both directions, and checks:
 *   - ascending sort is fully ordered, descending sort is fully ordered;
 *   - min lands at a[0]/b[N-1] and max at a[N-1]/b[0];
 *   - the sum is preserved (a useful check, not a proof of multiset identity).
 * The shell checks the fixed-data line and the LCG min/max line separately.
 */
#include <stdlib.h>
#include <stdio.h>

#define N 200

/* A qsort/bsearch comparator carries __z88dk_callback (from <stdlib.h>): the library
 * sort thunk invokes it with SDCC's default (sdcccall0) order, so it expands to
 * __attribute__((sdcccall(0))) under llvmz80 and to nothing for sccz80/sdcc.
 * Portable across all three compilers with no #ifdef here.  See ravn/llvm-z80#279. */
__z88dk_callback int cmp_asc(const void *a, const void *b) {
    return *(const int *)a - *(const int *)b;
}

__z88dk_callback int cmp_desc(const void *a, const void *b) {
    return *(const int *)b - *(const int *)a;
}

static void check_callback_abi(void) {
    static int asc[] = {7, -3, 1, 7, 0};
    static int desc[] = {7, -3, 1, 7, 0};

    qsort(asc, 5, sizeof(int), cmp_asc);
    qsort(desc, 5, sizeof(int), cmp_desc);
    printf("callback asc=%d,%d,%d,%d,%d desc=%d,%d,%d,%d,%d\n",
           asc[0], asc[1], asc[2], asc[3], asc[4],
           desc[0], desc[1], desc[2], desc[3], desc[4]);
}

/* Deterministic 16-bit LCG (all math stays in 16 bits via natural overflow). */
static unsigned int lcg_state;
static unsigned int lcg_next(void) {
    lcg_state = (unsigned int)(lcg_state * 25173u + 13849u);
    return lcg_state;
}

static int is_sorted(const int *v, int n, int ascending) {
    int i;
    for (i = 1; i < n; i++) {
        if (ascending  && v[i] < v[i-1]) return 0;
        if (!ascending && v[i] > v[i-1]) return 0;
    }
    return 1;
}

static long sum_of(const int *v, int n) {
    long s = 0;
    int i;
    for (i = 0; i < n; i++) s += v[i];
    return s;
}

int main(void) {
    static int a[N], b[N];
    long sum_before, sum_a, sum_b;
    int i, ok;

    check_callback_abi();

    lcg_state = 0xACE1u;
    for (i = 0; i < N; i++) {
        int v = (int)(lcg_next() % 1000u);   /* 0..999 */
        a[i] = v;
        b[i] = v;
    }
    sum_before = sum_of(a, N);

    qsort(a, N, sizeof(int), cmp_asc);
    qsort(b, N, sizeof(int), cmp_desc);

    sum_a = sum_of(a, N);
    sum_b = sum_of(b, N);

    ok = is_sorted(a, N, 1) && is_sorted(b, N, 0)
       && a[0] == b[N-1] && a[N-1] == b[0]
       && sum_before == sum_a && sum_before == sum_b;

    /* Prints: qsort 200 <min> <max> OK   (min/max are deterministic) */
    printf("qsort %d %d %d %s\n", N, a[0], a[N-1], ok ? "OK" : "BAD");
    fflush(stdout);
    return 0;
}
