/* Runtime test for the z88dk-triple binary32 arithmetic lowering,
 * ravn/llvm-z80 #277.
 *
 * The triple lowers arithmetic to existing cm32_sdcc_* runtime entries. This
 * checks exact results by bit pattern and forces runtime calls with volatile
 * operands; subtraction and division are tested in both operand orders.
 */
#include <stdio.h>
#include <string.h>

typedef unsigned long u32;

static int fails = 0;

static u32 bits(float f) { u32 x; memcpy(&x, &f, 4); return x; }

static void chk_bits(const char *name, float got, u32 want) {
    u32 g = bits(got);
    if (g != want) {
        printf("FAIL %s: got %08lx want %08lx\n", name, g, want);
        fails++;
    }
}

static void chk(const char *name, float got, float want) {
    u32 g = bits(got), w = bits(want);
    if (g != w) {
        printf("FAIL %s: got %08lx want %08lx\n", name, g, w);
        fails++;
    }
}

/* volatile source operands -> real runtime libcalls (no constant folding) */
static volatile float f2 = 2.0f, f4 = 4.0f, f6 = 6.0f, f8 = 8.0f;
static volatile float fhalf = 0.5f, fquarter = 0.25f, f1 = 1.0f, f1_5 = 1.5f;
static volatile float fneg3 = -3.0f, f3 = 3.0f, fneg8 = -8.0f;
static volatile float fzero = 0.0f;
static volatile union { u32 u; float f; } qnan = { 0x7fc00000UL };
static volatile union { u32 u; float f; } pinf = { 0x7f800000UL };

int main(void) {
    /* add (commutative) */
    chk("add",       f2 + f2,   4.0f);
    chk("add.frac",  fhalf + fquarter, 0.75f);
    chk("add.comm",  f6 + f2,   8.0f);

    /* mul (commutative) */
    chk("mul",       f2 * f4,   8.0f);
    chk("mul.frac",  fhalf * fhalf, 0.25f);

    /* sub (order-sensitive) */
    chk("sub",       f6 - f2,   4.0f);
    chk("sub.rev",   f2 - f6,  -4.0f);   /* catches b-a bug */
    chk("sub.frac",  f1_5 - fhalf, 1.0f);
    chk("sub.zero",  f4 - f4,   0.0f);   /* +0, not -0: catches negate-approach */

    /* div (order-sensitive) */
    chk("div",       f8 / f2,   4.0f);
    chk("div.rev",   f2 / f8,   0.25f);  /* catches b/a bug */
    chk("div.frac",  f1 / f4,   0.25f);
    chk("div.neg",   fneg8 / f2, -4.0f); /* exactly representable quotient */
    /* Restrict division checks to exactly representable quotients: math32's
     * reciprocal-based division can differ by one ULP for other inputs. */

    /* signs */
    chk("mul.neg",   fneg3 * f2, -6.0f);
    chk("add.neg",   fneg3 + f3,  0.0f);

    /* z88dk documents canonical quiet-NaN output as 0x7fffffff. */
    chk_bits("nan.add.left",  qnan.f + f2, 0x7fffffffUL);
    chk_bits("nan.add.right", f2 + qnan.f, 0x7fffffffUL);
    chk_bits("nan.sub.left",  qnan.f - f2, 0x7fffffffUL);
    chk_bits("nan.sub.right", f2 - qnan.f, 0x7fffffffUL);
    chk_bits("nan.mul.left",  qnan.f * f2, 0x7fffffffUL);
    chk_bits("nan.mul.right", f2 * qnan.f, 0x7fffffffUL);
    chk_bits("nan.div.left",  qnan.f / f2, 0x7fffffffUL);
    chk_bits("nan.div.right", f2 / qnan.f, 0x7fffffffUL);

    /* Invalid operations yield NaN; infinite results are controls. */
    chk_bits("invalid.zero_times_inf", fzero * pinf.f, 0x7fffffffUL);
    chk_bits("invalid.zero_div_zero", fzero / fzero, 0x7fffffffUL);
    chk_bits("invalid.inf_div_inf", pinf.f / pinf.f, 0x7fffffffUL);
    chk_bits("invalid.inf_minus_inf", pinf.f - pinf.f, 0x7fffffffUL);
    chk_bits("inf.plus_finite", pinf.f + f2, 0x7f800000UL);
    chk_bits("inf.finite_div_zero", f2 / fzero, 0x7f800000UL);
    chk_bits("inf.finite_div_inf", f2 / pinf.f, 0x00000000UL);

    if (fails == 0)
        printf("ALL PASS\n");
    else
        printf("%d FAIL\n", fails);
    return fails;
}
