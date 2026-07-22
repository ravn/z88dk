/* runtime_printf_ieee.c -- transparent IEEE-754 printf via the opt-in
 * __LLVMZ80_IEEE_PRINTF header routing.
 *
 * This uses STOCK printf/snprintf (no __llvmz80_ prefix).  When compiled with
 * -D__LLVMZ80_IEEE_PRINTF, stdio.h routes them to the nanoprintf-backed shim in
 * softfloat_cpm_z80.lib, so `printf("%f", x)` prints correct IEEE binary64
 * instead of the math48 garbage stock z88dk printf would produce for clang's
 * doubles.  All other specifiers keep working.
 *
 * Green: prints "PASS ieee printf" after checking int/str/hex/%f/precision.
 */
#include <stdio.h>
#include <string.h>

int main(void) {
    int ok = 1;
    char buf[32];

    /* integer/string/hex still correct through the shim */
    snprintf(buf, sizeof buf, "%d,%s,%x", 42, "hi", 255);
    if (strcmp(buf, "42,hi,ff") != 0) { printf("FAIL int/str/hex [%s]\n", buf); ok = 0; }

    /* IEEE %f — the whole point */
    snprintf(buf, sizeof buf, "%f", 3.14159265358979);
    if (strcmp(buf, "3.141593") != 0) { printf("FAIL %%f [%s]\n", buf); ok = 0; }

    snprintf(buf, sizeof buf, "%.2f", 2.5);
    if (strcmp(buf, "2.50") != 0) { printf("FAIL %%.2f [%s]\n", buf); ok = 0; }

    snprintf(buf, sizeof buf, "%f", -0.5);
    if (strcmp(buf, "-0.500000") != 0) { printf("FAIL neg %%f [%s]\n", buf); ok = 0; }

    if (ok) printf("PASS ieee printf: stock printf(\"%%f\") routes to nanoprintf\n");
    return 0;
}
