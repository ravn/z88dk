/* Caller TU for ravn/z88dk#5 / #14 regression test.
 *
 * Sees only the ANSI prototype of zero_ctx().  Under --sdcccall 1,
 * emits register-args ABI (arg in HL).
 *
 * The callee TU (test_kr_regparm_callee.c) defines zero_ctx in K&R
 * form, which pre-fix forced SDCC to silently emit stack-args ABI
 * for the body.  Caller / callee disagreed -> the bug.
 *
 * Post-fix (sdcc-kr-regparm-preserve-z88dk.patch) preserves
 * SPEC_REGPARM/SPEC_ARGREG across the K&R parameter-type
 * replacement in mergeKRDeclListIntoFuncDecl, so the K&R callee
 * uses register-args matching the caller.
 *
 * Verifier: write 0xA5 at 0xCFFF if local got zeroed (correct,
 * PASS), or anything else if decoy at 0xC700 got zeroed instead
 * (BUG).
 */

typedef unsigned char uint8_t;

#define DECOY_ADDR 0xC700

typedef struct {
    uint8_t key[32];
    uint8_t enckey[32];
    uint8_t deckey[32];
} ctx_t;

/* ANSI prototype -- caller will emit sdcccall 1 register-args. */
void zero_ctx(ctx_t *c);

int main(void) {
    ctx_t local;
    uint8_t i;
    uint8_t *r;

    /* Pre-fill local + decoy with non-zero pattern. */
    for (i = 0; i < 96; i++) ((uint8_t *)&local)[i] = 0xAA;
    for (i = 0; i < 96; i++) ((volatile uint8_t *)DECOY_ADDR)[i] = 0xAA;

    /* "Late-assigned r" pattern: forces compiler to keep DECOY_ADDR
     * in BC under --nogcse, so a buggy callee that mis-reads its
     * ctx parameter from the stack-arg slot picks up BC=DECOY_ADDR
     * and zeros memory there.  Pre-fix: decoy gets zeroed.
     * Post-fix: local gets zeroed, decoy untouched. */
    r = (uint8_t *)DECOY_ADDR;
    for (i = 0; i < 16; i++) r[i] = 0xBB;

    zero_ctx(&local);

    /* Use r again after the call so the compiler keeps it alive
     * (otherwise dead-store elimination might drop r before the
     *  call site, masking the bug). */
    for (i = 16; i < 32; i++) r[i] = 0xCC;

    /* PASS verifier: local fully zeroed AND decoy untouched. */
    {
        uint8_t local_zeroed = 1;
        uint8_t decoy_intact = 1;
        for (i = 0; i < 96; i++) {
            if (((uint8_t *)&local)[i] != 0) { local_zeroed = 0; break; }
        }
        /* Decoy bytes 0..15 were 0xBB, 16..31 were 0xCC, rest were 0xAA. */
        for (i = 0; i < 16; i++) {
            if (((volatile uint8_t *)DECOY_ADDR)[i] != 0xBB) { decoy_intact = 0; break; }
        }
        if (local_zeroed && decoy_intact) {
            *((volatile uint8_t *)0xCFFF) = 0xA5;  /* PASS */
        } else {
            *((volatile uint8_t *)0xCFFF) = (uint8_t)(0x10 | (local_zeroed << 1) | decoy_intact);
        }
    }

    return 0;
}
