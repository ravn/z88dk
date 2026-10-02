/* Runtime test for the ravn/llvm-z80 clang f32 compare lowering to existing
 * z88dk math32 predicate entry points.
 * ravn/llvm-z80 #277 (follow-up to runtime_float.c/runtime_fconv.c).
 *
 * The current z88dk runtime test policy excludes NaNs, so this test covers
 * finite values only; behavior for NaNs is not asserted or verified here.
 * It verifies equality and relational results plus the finite-value behavior
 * of the C99 islessgreater predicate; it makes no claim about NaN semantics.
 *
 * `!=` and `islessgreater` agree for finite inputs; NaN behavior is outside
 * the supported runtime domain.
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
    /* == (oeq) */
    chk("eq.eq",  f2 == f2b, 1);
    chk("eq.lt",  f1 == f2,  0);
    chk("eq.gt",  f3 == f2,  0);

    /* != (une), equivalent to ordered not-equal for finite values */
    chk("ne.eq",  f2 != f2b, 0);
    chk("ne.lt",  f1 != f2,  1);
    chk("ne.gt",  f3 != f2,  1);

    /* < (olt) */
    chk("lt.eq",  f2 < f2b, 0);
    chk("lt.lt",  f1 < f2,  1);
    chk("lt.gt",  f3 < f2,  0);

    /* <= (ole) */
    chk("le.eq",  f2 <= f2b, 1);
    chk("le.lt",  f1 <= f2,  1);
    chk("le.gt",  f3 <= f2,  0);

    /* > (ogt) */
    chk("gt.eq",  f2 > f2b, 0);
    chk("gt.lt",  f1 > f2,  0);
    chk("gt.gt",  f3 > f2,  1);

    /* >= (oge) */
    chk("ge.eq",  f2 >= f2b, 1);
    chk("ge.lt",  f1 >= f2,  0);
    chk("ge.gt",  f3 >= f2,  1);

    /* islessgreater (one): ordered not-equal for finite values */
    chk("one.eq",  __builtin_islessgreater(f2, f2b), 0);
    chk("one.lt",  __builtin_islessgreater(f1, f2),  1);
    chk("one.gt",  __builtin_islessgreater(f3, f2),  1);

    if (fails == 0)
        printf("ALL PASS\n");
    else
        printf("%d FAIL\n", fails);
    return fails;
}
