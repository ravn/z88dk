/* Runtime test for f32 finite comparisons under -ffast-math, using the
 * ravn/llvm-z80 lowering to existing z88dk math32 predicates.
 * ravn/llvm-z80 #277 follow-up.
 *
 * NaNs are outside the current runtime-test policy and are not asserted.
 */
#include <stdio.h>

static int fails = 0;

static void chk(const char *name, int got, int want) {
    if ((got != 0) != (want != 0)) {
        printf("FAIL %s: got %d want %d\n", name, got, want);
        fails++;
    }
}

/* volatile -> real libcalls, no constant folding */
static volatile float f1 = 1.0f, f2 = 2.0f, f2b = 2.0f, f3 = 3.0f;

int main(void) {
    chk("eq.eq", f2 == f2b, 1);
    chk("eq.lt", f1 == f2, 0);
    chk("eq.gt", f3 == f2, 0);

    chk("ne.eq", f2 != f2b, 0);
    chk("ne.lt", f1 != f2, 1);
    chk("ne.gt", f3 != f2, 1);

    chk("lt.lt", f1 < f2, 1);
    chk("lt.eq", f2 < f2b, 0);
    chk("lt.gt", f3 < f2, 0);

    chk("le.lt", f1 <= f2, 1);
    chk("le.eq", f2 <= f2b, 1);
    chk("le.gt", f3 <= f2, 0);

    chk("gt.lt", f1 > f2, 0);
    chk("gt.eq", f2 > f2b, 0);
    chk("gt.gt", f3 > f2, 1);

    chk("ge.lt", f1 >= f2, 0);
    chk("ge.eq", f2 >= f2b, 1);
    chk("ge.gt", f3 >= f2, 1);

    if (fails == 0)
        printf("ALL PASS\r\n");
    else
        printf("%d FAILURES\r\n", fails);

    return 0;
}
