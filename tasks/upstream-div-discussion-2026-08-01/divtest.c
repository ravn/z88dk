/* Shared timing-test source: math32's own division (Newton-Raphson
 * reciprocal) vs. a direct restoring-division reference (see
 * directdiv.h), same operands, same loop count, same file -- so the two
 * .com files differ ONLY in which division routine is exercised.
 *
 * Build A (math32, current behaviour):
 *   zcc +cpm -compiler=sdcc -O2 -create-app -DUSE_MATH32 -lmath32 \
 *       -o math32_div_test divtest.c
 * Build B (direct restoring division):
 *   zcc +cpm -compiler=sdcc -O2 -create-app -o directdiv_test divtest.c
 *
 * Measure either with:
 *   z88dk-ticks math32_div_test.com
 *   z88dk-ticks directdiv_test.com
 *
 * The result is extracted via raw bit-pattern (not a float->int cast) so
 * neither build needs to link any float<->int conversion routine -- Build
 * B deliberately links NO float library at all, to isolate the division
 * algorithm itself from anything else.
 */
#ifndef USE_MATH32
#include "directdiv.h"
#endif

static volatile float a = 3.14159f, b = 2.71828f;

int main(void) {
    unsigned i;
    volatile float rf = 0;
    union { float f; unsigned long u; } r;

    for (i = 0; i < 2000; i++) {
#ifdef USE_MATH32
        rf = a / b;
#else
        rf = direct_div(a, b);
#endif
    }

    r.f = rf;
    return (int)(r.u & 0xFFu);
}
