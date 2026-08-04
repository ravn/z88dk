/* issue22_stdio_fputs.c -- regression guard for ravn/z88dk#22.
 *
 * #22: under -compiler=llvmz80, fputs() warm-boot-looped. Root cause was the
 * register-vs-stack ABI mismatch: the generic __ZPROTO2 clang branch called the
 * classic worker ___fputs with args in HL/DE, but _fputs is a __smallc stack
 * worker (pop bc=fp / pop de=s). The garbage FILE* corrupted SP -> restart loop.
 *
 * Fixed in include/stdio.h by binding fputs straight to the classic worker via a
 * reversed-param __smallc prototype under __LLVMZ80 (fp declared first, matching
 * the worker's top-of-stack read) -- the same pattern already used for fopen/
 * freopen/fread/fwrite/fseek/fflush.
 *
 * GREEN: fputs("BC",f) returns >0, the bytes read back as B,C, prints DONE.
 * RED (pre-fix): warm-boot restart loop (reprints "opened" forever).
 */
#include <stdio.h>

int main(void)
{
    FILE *f = fopen("FS.DAT", "wb");
    printf("opened\n"); fflush(stdout);
    int r = fputs("BC", f);
    printf("fputs=%d\n", r); fflush(stdout);   /* want > 0 */
    fclose(f);

    f = fopen("FS.DAT", "rb");
    int a = fgetc(f), b = fgetc(f);
    fclose(f);
    printf("read=%c%c\n", a, b);               /* want BC */
    printf("DONE\n");
    return 0;
}
