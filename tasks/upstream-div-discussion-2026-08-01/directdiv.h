#ifndef DIRECTDIV_H
#define DIRECTDIV_H

/* Reference "direct restoring division" implementation for float32,
 * mirroring the algorithm compiler-rt's __divsf3 uses on z80 (see
 * llvm-z80 compiler-rt/lib/builtins/z80/divsf3.asm): unpack sign/exponent
 * /24-bit mantissa, do a 24-iteration binary restoring-division loop on the
 * mantissas (compare/subtract/shift, no multiply), then round and repack.
 *
 * This is a PROOF-OF-CONCEPT for the timing question only -- it omits
 * NaN/Inf/zero/denormal special-casing (compiler-rt's real routine handles
 * all of those; see the .asm for the full state machine). It is correct
 * for ordinary finite non-zero operands, which is all the benchmark needs.
 */

typedef union { float f; unsigned long u; } f2u_t;

float direct_div(float a, float b) {
    f2u_t ua, ub, ur;
    unsigned long mant_a, mant_b, quotient, remainder;
    unsigned char sign, guard, i;
    int result_exp;

    ua.f = a;
    ub.f = b;

    sign = (unsigned char)(((ua.u >> 31) ^ (ub.u >> 31)) & 1);

    result_exp = (int)((ua.u >> 23) & 0xFF) - (int)((ub.u >> 23) & 0xFF) + 127;

    mant_a = (ua.u & 0x7FFFFFUL) | 0x800000UL;   /* restore implicit bit */
    mant_b = (ub.u & 0x7FFFFFUL) | 0x800000UL;

    /* Pre-normalize: ensure dividend >= divisor so the first quotient
     * bit is always 1 (same trick compiler-rt uses, __div_pre_norm). */
    if (mant_a < mant_b) {
        mant_a <<= 1;
        result_exp -= 1;
    }

    quotient = 0;
    remainder = mant_a;
    for (i = 0; i < 24; i++) {
        quotient <<= 1;
        if (remainder >= mant_b) {
            remainder -= mant_b;
            quotient |= 1;
        }
        remainder <<= 1;
    }

    /* Round to nearest: one more comparison gives the guard bit. */
    guard = (remainder >= mant_b) ? 1 : 0;
    if (guard) {
        quotient += 1;
        if (quotient & 0x1000000UL) {   /* mantissa overflow -> renormalize */
            quotient >>= 1;
            result_exp += 1;
        }
    }

    ur.u = ((unsigned long)sign << 31)
         | ((unsigned long)(result_exp & 0xFF) << 23)
         | (quotient & 0x7FFFFFUL);
    return ur.f;
}

#endif
