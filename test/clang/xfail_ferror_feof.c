/* xfail_ferror_feof.c -- documents a REAL llvmz80 divergence on classic +cpm:
 * ferror() and feof() return GARBAGE under llvmz80 where sccz80 is correct.
 *
 * Root cause (empirically confirmed, 2026-08-10): stdio.h declares
 *     extern int ferror(FILE *fp);            // plain, no __smallc/fastcall
 *     #ifndef __STDC_ABI_ONLY
 *     extern int ferror_fastcall(FILE*) __z88dk_fastcall;
 *     #define ferror(f) ferror_fastcall(f)
 *     #endif
 * (feof is identical).  Under llvmz80, __STDC_ABI_ONLY is in effect, so the
 * fastcall macro is skipped and the PLAIN `ferror` is used.  clang then
 * tail-calls the hand-asm `_ferror` (`jp _ferror`) passing the FILE* per
 * sdcccall(1) in a register -- but `_ferror`'s asm entry uses the classic
 * STACK-arg convention (`pop de` / `pop hl`), so it reads a bogus pointer and
 * returns garbage.  sccz80 uses the same asm with the matching stack ABI, so
 * it is correct.
 *
 * Contrast: fileno works because it is declared `__smallc __z88dk_fastcall`
 * UNCONDITIONALLY (stdio.h:206); the fix for ferror/feof is to give them the
 * same unconditional bridged ABI (or a __ZPROTO form) so llvmz80 stops hitting
 * the stack-arg entry.
 *
 * This is an ORACLE-DIFF XFAIL (see xfail_ferror_feof.sh).  It probes ferror/
 * feof across the whole contract and prints one token per state; sccz80 defines
 * the correct answer and llvmz80 must match it.  The four states cover BOTH
 * feof branches:
 *   - fresh stream (feof=0, ferror=0)
 *   - mid-file     (feof=0, ferror=0)
 *   - true EOF     (feof=1, ferror=0)   <-- see the RECSZ note below
 *   - after clearerr (feof=1: clearerr is a no-op macro on classic +cpm)
 *
 * RECSZ note: classic +cpm feof only latches on a genuine zero-length read at a
 * RECORD boundary.  A partial last record is padded with 0x1a (^Z) and never
 * yields EOF, so a short file's feof stays 0 forever.  We therefore make the
 * file EXACTLY one 128-byte record: after reading all 128 bytes, one more fgetc
 * returns -1 (EOF) and feof latches to 1.  (Empirically: 128-byte file -> real
 * EOF; 129-byte -> fgetc returns 0x1a and feof stays 0.)
 */
#include <stdio.h>

#define RECSZ 128

int main(void) {
    FILE *f;
    int i, c;
    int f_fresh, r_fresh, f_mid, r_mid, f_eof, r_eof, f_clr, r_clr;

    f = fopen("XE.DAT", "wb");
    if (!f) { puts("xff[FAIL make]"); return 1; }
    for (i = 0; i < RECSZ; i++) fputc(0x41 + (i & 15), f);   /* one full record */
    fclose(f);

    f = fopen("XE.DAT", "rb");
    if (!f) { puts("xff[FAIL open]"); return 1; }

    /* (1) fresh stream: nothing read yet */
    f_fresh = feof(f) != 0;
    r_fresh = ferror(f) != 0;

    /* (2) mid-file: after reading half the record */
    for (i = 0; i < RECSZ / 2; i++) (void)fgetc(f);
    f_mid = feof(f) != 0;
    r_mid = ferror(f) != 0;

    /* (3) true EOF: drain the rest of the record, then one read past the end
     * (returns -1 at the record boundary) latches feof. */
    for (i = RECSZ / 2; i < RECSZ; i++) (void)fgetc(f);
    c = fgetc(f);                     /* -1 (EOF) on a correct impl */
    f_eof = feof(f) != 0;             /* expect 1 */
    r_eof = ferror(f) != 0;           /* expect 0 (EOF is not an error) */

    /* (4) after clearerr: on classic +cpm clearerr is a NO-OP macro
     * (#define clearerr(f) with an empty body, stdio.h:202), so feof stays
     * SET here -- the oracle reports f_clr=1.  (ISO C would reset it; this
     * fixture records what z88dk classic actually does.) */
    clearerr(f);
    f_clr = feof(f) != 0;
    r_clr = ferror(f) != 0;

    fclose(f);
    remove("XE.DAT");

    (void)c;
    /* one token per state -- sccz80 is the oracle, llvmz80 must match */
    printf("ff f_fresh=%d r_fresh=%d f_mid=%d r_mid=%d f_eof=%d r_eof=%d f_clr=%d r_clr=%d\n",
           f_fresh, r_fresh, f_mid, r_mid, f_eof, r_eof, f_clr, r_clr);
    return 0;
}
