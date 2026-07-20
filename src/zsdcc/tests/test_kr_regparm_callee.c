/* Callee TU for ravn/z88dk#5 / #14 regression test.
 *
 * K&R-style definition.  Pre-fix: SDCC silently emits stack-args
 * ABI for the body (reads ctx from `(ix+4)`) even though --sdcccall 1
 * is set.  Post-fix (sdcc-kr-regparm-preserve-z88dk.patch): the K&R
 * parameter retains its REGPARM marking from processFuncArgs across
 * the merge with the declaration list, so the body uses register-args
 * matching what ANSI-prototype callers emit.
 *
 * Body shape mirrors aes_done() in aes256.c — single pointer arg
 * that gets used for repeated array writes inside a loop.
 */

typedef unsigned char uint8_t;

typedef struct {
    uint8_t key[32];
    uint8_t enckey[32];
    uint8_t deckey[32];
} ctx_t;

/* K&R-style: no prototype, parameter declared on next line. */
void zero_ctx(c) ctx_t *c;
{
    register uint8_t i;
    for (i = 0; i < 32; i++)
        c->key[i] = c->enckey[i] = c->deckey[i] = 0;
}
