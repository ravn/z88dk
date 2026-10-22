/* Runtime testsuite: 32-bit integer arithmetic (long on Z80).
 *
 * Exercises the compiler-generated calls to:
 *   l_mulu_16_16x16, l_mulu_32x32   (unsigned 32-bit multiply)
 *   __divsi3 / __udivsi3            (signed/unsigned 32-bit divide)
 *   __modsi3 / __umodsi3            (signed/unsigned 32-bit modulo)
 *   __ashlsi3 / __ashrsi3 / __lshrsi3  (32-bit shifts)
 *
 * KNOWN LIMITATION: signed 32-bit multiply hits llvm-z80 backend assert
 *   `fatal error: unable to legalize instruction: G_MUL (s32)`
 * (ravn/z88dk#91 blocker 2).  This file therefore only tests UNSIGNED
 * 32-bit multiply.  Add signed-mul coverage once the backend lands the
 * s32 legalizer fix.
 *
 * The 32-bit library helpers live in z80iy_crt0.lib (not cpm_clib.lib),
 * so a non-ixiy link chain fails here on the first `long` divide.
 *
 * FUTURE WORK: 64-bit (long long) arithmetic is NOT tested here because
 * no z88dk library ships the required helpers.  llvmz80's backend emits
 * calls to ___divdi3 / ___muldi3 / ___moddi3 / ___udivdi3 / ___umoddi3
 * for `long long` ops, but every target's clib fails at link with
 * "undefined symbol: ___divdi3" etc.  A `runtime_arith64.c` cannot be
 * added until either (a) the helpers are built into some crt0 lib,
 * or (b) the backend lowers 64-bit arithmetic without external calls.
 * This is a separate gap from the ixiy packaging issue tracked in
 * ravn/z88dk#91 -- #91's ___z80_memset_builtin exists in z80iy_crt0.lib,
 * while ___divdi3 doesn't exist anywhere.  `long long` currently works
 * only for storage / variadic pass-through, not arithmetic.
 *
 * Hardening against ABI parameter-order bugs:
 *   - Operands differ by magnitude so a swap of a/b changes the result
 *     (e.g. 100/7 = 14 but 7/100 = 0 -- distinct).
 *   - Signed tests use mixed sign so sign-handling bugs surface.
 *   - Operands kept in volatile so compiler cannot fold at compile time.
 *
 * Exit codes are distinct per probe. */
#include <stdio.h>
#include <stdlib.h>

static volatile long va, vb;
static volatile unsigned long ua, ub;

int main(void)
{
    long r;
    unsigned long ur;

    /* === Unsigned 32-bit multiply === */

    ua = 7UL; ub = 11UL;
    ur = ua * ub;
    if (ur != 77UL) return 10;

    ua = 1000UL; ub = 1000UL;
    ur = ua * ub;
    if (ur != 1000000UL) return 11;

    /* Asymmetric magnitude so a swap would produce a different result */
    ua = 65537UL; ub = 3UL;
    ur = ua * ub;
    if (ur != 196611UL) return 12;

    /* 16x16 widening */
    ua = 30000UL; ub = 30000UL;
    ur = ua * ub;
    if (ur != 900000000UL) return 13;

    /* Multiply with 0 */
    ua = 0UL; ub = 999999UL;
    ur = ua * ub;
    if (ur != 0UL) return 14;

    /* Multiply by 1 identity */
    ua = 1234567UL; ub = 1UL;
    ur = ua * ub;
    if (ur != 1234567UL) return 15;

    /* === __divsi3 (signed 32-bit divide) === */

    va = 100L; vb = 7L;
    r = va / vb;
    if (r != 14L) return 20;

    /* Swap detection: 100/7 = 14 but 7/100 = 0 -- different results */
    va = 7L; vb = 100L;
    r = va / vb;
    if (r != 0L) return 21;

    /* Negative dividend (C99 truncation toward zero) */
    va = -100L; vb = 7L;
    r = va / vb;
    if (r != -14L) return 22;

    /* Negative divisor */
    va = 100L; vb = -7L;
    r = va / vb;
    if (r != -14L) return 23;

    /* Both negative */
    va = -100L; vb = -7L;
    r = va / vb;
    if (r != 14L) return 24;

    /* Large values */
    va = 1000000L; vb = 123L;
    r = va / vb;
    if (r != 8130L) return 25;

    /* Divide by 1 identity */
    va = 1234567L; vb = 1L;
    r = va / vb;
    if (r != 1234567L) return 26;

    /* === __modsi3 (signed 32-bit modulo) === */

    va = 100L; vb = 7L;
    r = va % vb;
    if (r != 2L) return 30;

    /* Swap detection: 100%7=2 but 7%100=7 */
    va = 7L; vb = 100L;
    r = va % vb;
    if (r != 7L) return 31;

    /* Negative dividend: C99 says result sign == dividend sign */
    va = -100L; vb = 7L;
    r = va % vb;
    if (r != -2L) return 32;

    va = 100L; vb = -7L;
    r = va % vb;
    if (r != 2L) return 33;

    /* === __udivsi3 / __umodsi3 (unsigned 32-bit divide/mod) === */

    ua = 100UL; ub = 7UL;
    ur = ua / ub;
    if (ur != 14UL) return 40;

    /* Large value */
    ua = 0xDEADBEEFUL; ub = 123UL;
    ur = ua / ub;
    if (ur != 30373402UL) return 41;

    ua = 0xFFFFFFFFUL; ub = 1UL;
    ur = ua / ub;
    if (ur != 0xFFFFFFFFUL) return 42;

    ua = 100UL; ub = 7UL;
    ur = ua % ub;
    if (ur != 2UL) return 43;

    ua = 0xDEADBEEFUL; ub = 123UL;
    ur = ua % ub;
    if (ur != 113UL) return 44;

    /* === 32-bit shifts === */

    /* Logical left */
    va = 1L;
    r = va << 16;
    if (r != 0x10000L) return 50;

    va = 0x12345L;
    r = va << 4;
    if (r != 0x123450L) return 51;

    /* Arithmetic right (signed) */
    va = -1024L;
    r = va >> 3;
    if (r != -128L) return 52;

    /* Logical right (unsigned) */
    ua = 0x80000000UL;
    ur = ua >> 4;
    if (ur != 0x08000000UL) return 53;

    /* Shift by variable count -- forces runtime call */
    for (int i = 0; i < 16; ++i) {
        va = 1L;
        r = va << i;
        if (r != (1L << i)) return 54;
    }

    printf("ALL PASS\n");
    return 0;
}
