/* Runtime regression test for qsort with a clang/llvmz80 comparator.
 *
 * INSIGHT UNDER TEST (z88dk maintainer's "annotate the callback" approach):
 *   z88dk's qsort_sdcc_callee invokes the user comparator with sdcccall(0)
 *   semantics -- arguments on the stack ([SP+2]=a, [SP+4]=b) and the int
 *   result read from HL (see libsrc/classic/stdlib/qsort_sdcc_callee.asm).
 *   A DEFAULT clang comparator instead takes a in HL, b in DE and returns in
 *   DE, which qsort_sdcc cannot invoke -> the sort scrambles the array.
 *
 *   Declaring the comparator __smallc (== __attribute__((sdcccall(0))) for
 *   clang, a no-op for sccz80/sdcc) makes clang compile it to read a/b from
 *   the stack and return in HL -- exactly qsort_sdcc's callback protocol.
 *   No runtime trampoline or global state is needed; the sort is reentrant.
 *   <stdlib.h>'s qsort() macro supplies the matching inline call-order swapper
 *   for the four qsort arguments (the __ZPROTO4 mechanism).
 *
 * RED (pre-insight): an unannotated comparator -> array left unsorted/garbage.
 * GREEN: __smallc comparator -> array fully sorted.
 *
 * A larger dataset (N=200 pseudo-random ints from a deterministic 16-bit LCG)
 * exercises the callback thousands of times through the quicksort recursion in
 * both directions, and checks:
 *   - ascending sort is fully ordered, descending sort is fully ordered;
 *   - min lands at a[0]/b[N-1] and max at a[N-1]/b[0];
 *   - the element multiset is preserved (sum before == sum after) so a broken
 *     comparator that drops/duplicates elements is caught even if the tail
 *     happens to look ordered.
 * The program prints a single result line the .sh harness matches exactly.
 */
#include <stdlib.h>
#include <stdio.h>

#define N 200

/* __smallc == sdcccall(0) for clang; empty for sccz80/sdcc (source-portable). */
__smallc int cmp_asc(const void *a, const void *b) {
    return *(const int *)a - *(const int *)b;
}

__smallc int cmp_desc(const void *a, const void *b) {
    return *(const int *)b - *(const int *)a;
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
