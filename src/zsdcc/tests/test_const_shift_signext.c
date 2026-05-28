/* Regression test for ravn/z88dk#4: zsdcc const-expression
 * (uint16_t)X >> 8 sign-extends a bit-7-set byte to 0xFF instead of 0x00.
 *
 * Minimal pure-literal trigger:
 *   ((uint16_t)((0x80 | 0) | (0 << 8)) >> 8) & 0xFF
 * Per C, (uint16_t)0x80 >> 8 == 0.  But zsdcc 4.5.0 #15242 folds it to 0xFF.
 *
 * Mechanism (SDCCval.c): the nested OR (0x80|0) is reduced by cheapestVal to
 * unsigned char 128; the outer `| (0<<8)` then goes through valBitwise, whose
 * computeType(unsigned char, int, RESULT_TYPE_CHAR, '|') returns a SIGNED char
 * result type while storing the value 128 (out of signed-char range).  The
 * trailing cheapestVal bails because the result is already V_CHAR, so the
 * {signed char, 128} inconsistency survives; the later (uint16_t) cast reads
 * the 0x80 bit pattern as -128, sign-extends to 0xFF80, and >>8 yields 0xFF.
 *
 * Verifier @ 0xCFFF: 0xA5 iff the baked const HI byte == 0x00 AND LO == 0x80.
 *   pre-fix : HI const baked as 0xFF -> FAIL (sentinel = the wrong HI byte).
 *   post-fix: HI == 0x00            -> PASS (sentinel = 0xA5).
 */

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;

/* The buggy const-fold, in its minimal pure-literal form. */
const uint8_t hi = ((uint16_t)((0x80 | 0) | (0 << 8)) >> 8) & 0xFF; /* expect 0x00 */
const uint8_t lo = (uint16_t)((0x80 | 0) | (0 << 8)) & 0xFF;        /* expect 0x80 */

int main(void) {
    /* Read the baked const bytes through volatile pointers so the compiler
     * cannot re-fold (and thus re-corrupt or mask) the comparison. */
    volatile const uint8_t *php = &hi;
    volatile const uint8_t *plo = &lo;

    if (*php == 0x00 && *plo == 0x80)
        *((volatile uint8_t *)0xCFFF) = 0xA5;   /* PASS */
    else
        *((volatile uint8_t *)0xCFFF) = *php;    /* FAIL: report the wrong HI byte */

    return 0;
}
