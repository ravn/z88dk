/* Runtime fixture for libm entry points provided by z88dk math32.
 *
 * Float printf is unreliable on the classic/llvmz80 path, so we scale each
 * result by 1e4, truncate to int, and compare against a reference with a small
 * tolerance (last-ULP differences between libm implementations are expected).
 * sqrt is included as a control alongside the transcendental functions.
 */
#include <stdio.h>
#include <math.h>

static int fails = 0;

static void chk(const char *name, int got, int want)
{
    int d = got - want;
    if (d < 0) d = -d;
    if (d > 2) {                 /* +-2 in the 1e4-scaled integer */
        printf("FAIL %s: got %d want %d\n", name, got, want);
        fails++;
    }
}

int main(void)
{
    chk("sqrt2", (int)(sqrt(2.0)   * 10000.0),  14142);
    chk("exp.75",(int)(exp(0.75)   * 10000.0),  21170);
    chk("log.75",(int)(log(0.75)   * 10000.0),  -2876);
    chk("sin1",  (int)(sin(1.0)    * 10000.0),   8414);
    chk("cos1",  (int)(cos(1.0)    * 10000.0),   5403);
    chk("atan1", (int)(atan(1.0)   * 10000.0),   7853);  /* pi/4 */

    if (fails == 0)
        printf("ALL PASS\n");
    else
        printf("%d FAIL\n", fails);
    return 0;
}
