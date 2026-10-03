/* Runtime test for the ravn/llvm-z80 clang f32 compare lowering to existing
 * z88dk math32 predicate entry points.
 * ravn/llvm-z80 #277 (follow-up to runtime_float.c/runtime_fconv.c).
 *
 * Expected masks below come from IEEE comparison rules, not math32:
 * unordered predicates are true for either NaN operand, ordered ones false.
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

enum {
    EQ = 1, ONE = 2, LT = 4, LE = 8, GT = 16, GE = 32,
    ORD = 64, UNO = 128, UEQ = 256, UNE = 512,
    ULT = 1024, ULE = 2048, UGT = 4096, UGE = 8192
};

static volatile union { unsigned long u; float f; } lhs, rhs;

static __attribute__((noinline)) unsigned predicates(float a, float b) {
    return (a == b ? EQ : 0) | (__builtin_islessgreater(a,b) ? ONE : 0)
        | (a < b ? LT : 0) | (a <= b ? LE : 0)
        | (a > b ? GT : 0) | (a >= b ? GE : 0)
        | (!__builtin_isunordered(a,b) ? ORD : 0)
        | (__builtin_isunordered(a,b) ? UNO : 0)
        | (!__builtin_islessgreater(a,b) ? UEQ : 0) | (a != b ? UNE : 0)
        | (!__builtin_isgreaterequal(a,b) ? ULT : 0)
        | (!__builtin_isgreater(a,b) ? ULE : 0)
        | (!__builtin_islessequal(a,b) ? UGT : 0)
        | (!__builtin_isless(a,b) ? UGE : 0);
}

static void matrix(unsigned long a, unsigned long b, unsigned want) {
    lhs.u = a;
    rhs.u = b;
    unsigned got = predicates(lhs.f, rhs.f);
    if (got != want) {
        printf("FAIL predicates %08lx,%08lx: got %04x want %04x\n",
               a, b, got, want);
        fails++;
    }
}

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

    const unsigned equal = EQ | LE | GE | ORD | UEQ | ULE | UGE;
    const unsigned less = ONE | LT | LE | ORD | UNE | ULT | ULE;
    const unsigned greater = ONE | GT | GE | ORD | UNE | UGT | UGE;
    const unsigned unordered = UNO | UEQ | UNE | ULT | ULE | UGT | UGE;
    static const unsigned long nans[] = {
        0x7fc00000UL, 0xffc00000UL, 0x7fffffffUL, 0x7f800001UL
    };
    matrix(0x3f800000UL, 0x40000000UL, less);    /* 1 < 2 */
    matrix(0x40000000UL, 0x3f800000UL, greater);
    matrix(0x3f800000UL, 0x3f800000UL, equal);
    matrix(0, 0x80000000UL, equal);             /* +0 == -0 */
    matrix(0xff800000UL, 0x7f800000UL, less);    /* -Inf < +Inf */
    matrix(0x7f800000UL, 0x7f800000UL, equal);
    for (unsigned i = 0; i < sizeof(nans)/sizeof(nans[0]); ++i) {
        matrix(nans[i], 0x3f800000UL, unordered);
        matrix(0x3f800000UL, nans[i], unordered);
        matrix(nans[i], 0, unordered);
        matrix(0x7f800000UL, nans[i], unordered);
        matrix(nans[i], nans[i], unordered);
    }

    if (fails == 0)
        printf("ALL PASS\n");
    else
        printf("%d FAIL\n", fails);
    return fails;
}
