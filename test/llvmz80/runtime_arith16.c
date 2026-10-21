/* Runtime testsuite: 16-bit and 8-bit integer arithmetic (int, char).
 *
 * Exercises the compiler-generated calls to:
 *   __divhi3 / __udivhi3     (signed/unsigned 16-bit divide)
 *   __modhi3 / __umodhi3     (signed/unsigned 16-bit modulo)
 *   __mulhi3 / l_mulu_hl_de  (16-bit multiply)
 *   __udivqi3                (unsigned 8-bit divide)
 *   __ashlhi3 / __ashrhi3 / __lshrhi3  (16-bit shifts)
 *
 * On Z80 `int` is 16-bit, so these ops dominate general arithmetic in C
 * programs.  Many have inline (ADD HL,HL / SBC HL,DE / SUB) codegen paths
 * for constant shifts; the library helpers kick in for variable-count
 * shifts, non-power-of-2 divides, and arbitrary multiplies.
 *
 * Hardening against ABI parameter-order bugs:
 *   - Divide tests probe swap-asymmetric pairs (100/7=14 vs 7/100=0).
 *   - Sign quadrants (pos/pos, neg/pos, pos/neg, neg/neg) exercised.
 *   - Operands kept in volatile so compiler cannot fold at compile time.
 *
 * Exit codes are distinct per probe. */
#include <stdio.h>
#include <stdlib.h>

static volatile int vi, vj;
static volatile unsigned int vu, vv;
static volatile unsigned char vca, vcb;

int main(void)
{
    int r;
    unsigned int ur;

    /* === 16-bit signed multiply === */

    vi = 7; vj = 11;
    r = vi * vj;
    if (r != 77) return 10;

    /* Asymmetric so a swap would be visible */
    vi = 123; vj = 45;
    r = vi * vj;
    if (r != 5535) return 11;

    /* Negative × positive */
    vi = -7; vj = 11;
    r = vi * vj;
    if (r != -77) return 12;

    /* Negative × negative */
    vi = -7; vj = -11;
    r = vi * vj;
    if (r != 77) return 13;

    /* Multiply with 0 */
    vi = 0; vj = 32000;
    r = vi * vj;
    if (r != 0) return 14;

    /* Max positive × 2 — hits int wraparound at 2's complement */
    vi = 16384; vj = 2;
    r = vi * vj;
    if (r != -32768) return 15;  /* wraps to INT16_MIN */

    /* === 16-bit unsigned multiply === */

    vu = 1000; vv = 60;
    ur = vu * vv;
    if (ur != 60000U) return 16;

    vu = 256; vv = 256;
    ur = vu * vv;
    if (ur != 0U) return 17;  /* 65536 wraps to 0 in u16 */

    /* === __divhi3 (signed 16-bit divide) === */

    vi = 100; vj = 7;
    r = vi / vj;
    if (r != 14) return 20;

    /* Swap detection */
    vi = 7; vj = 100;
    r = vi / vj;
    if (r != 0) return 21;

    /* Four sign quadrants (C99 truncation toward zero) */
    vi = -100; vj = 7;
    r = vi / vj;
    if (r != -14) return 22;

    vi = 100; vj = -7;
    r = vi / vj;
    if (r != -14) return 23;

    vi = -100; vj = -7;
    r = vi / vj;
    if (r != 14) return 24;

    /* Large signed values */
    vi = 32000; vj = 100;
    r = vi / vj;
    if (r != 320) return 25;

    vi = -32000; vj = 100;
    r = vi / vj;
    if (r != -320) return 26;

    /* === __modhi3 (signed 16-bit modulo) === */

    vi = 100; vj = 7;
    r = vi % vj;
    if (r != 2) return 30;

    /* C99: result sign == dividend sign */
    vi = -100; vj = 7;
    r = vi % vj;
    if (r != -2) return 31;

    vi = 100; vj = -7;
    r = vi % vj;
    if (r != 2) return 32;

    /* === __udivhi3 / __umodhi3 (unsigned 16-bit) === */

    vu = 50000U; vv = 123U;
    ur = vu / vv;
    if (ur != 406U) return 40;

    vu = 50000U; vv = 123U;
    ur = vu % vv;
    if (ur != 62U) return 41;

    vu = 0xFFFFU; vv = 1U;
    ur = vu / vv;
    if (ur != 0xFFFFU) return 42;

    vu = 0xFFFFU; vv = 0x1234U;
    ur = vu / vv;
    if (ur != 14U) return 43;

    vu = 0xFFFFU; vv = 0x1234U;
    ur = vu % vv;
    if (ur != 295U) return 44;

    /* === __udivqi3 (unsigned 8-bit divide) === */

    vca = 100; vcb = 7;
    {
        unsigned char cr = vca / vcb;
        if (cr != 14) return 50;
        cr = vca % vcb;
        if (cr != 2) return 51;
    }

    vca = 200; vcb = 3;
    {
        unsigned char cr = vca / vcb;
        if (cr != 66) return 52;
        cr = vca % vcb;
        if (cr != 2) return 53;
    }

    /* === 16-bit shifts === */

    /* Variable count: forces runtime library call */
    for (int i = 0; i < 16; ++i) {
        vi = 1;
        r = vi << i;
        if (r != (1 << i)) return 60;
    }

    /* Logical right (unsigned) via variable count */
    for (int i = 0; i < 16; ++i) {
        vu = 0x8000U;
        ur = vu >> i;
        if (ur != (unsigned int)(0x8000U >> i)) return 61;
    }

    /* Arithmetic right (signed) sign extension */
    vi = -256;
    r = vi >> 2;
    if (r != -64) return 62;

    vi = -1;
    r = vi >> 4;
    if (r != -1) return 63;  /* all-ones stays all-ones */

    /* Constant shifts (likely inline codegen, not library) */
    vi = 0x1234;
    r = vi << 1;
    if (r != 0x2468) return 64;

    vi = 0x1234;
    r = vi >> 4;
    if (r != 0x0123) return 65;

    printf("ALL PASS\n");
    return 0;
}
