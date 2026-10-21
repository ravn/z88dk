/* Runtime testsuite: memory builtins and ZPROTO memory thunks.
 *
 * Exercises both paths the llvm-z80 backend emits for memset/memcpy:
 *   - _memset_callee / _memcpy_callee (ZPROTO __z88dk_callee thunks in
 *     cpm_clib.lib) for simple cases
 *   - __z80_memset_builtin / __z80_memcpy_builtin (ixiy crt0 helpers in
 *     z80iy_crt0.lib) for vectorised / larger ops
 *
 * The exact threshold between the two paths is a backend decision that may
 * change over time.  This test exercises a spectrum of sizes so both paths
 * get hit regardless of the current threshold.
 *
 * Hardening against parameter-order ABI bugs (the class PR #90 fixes):
 *   - Each test uses distinct asymmetric values so argument swapping leaves
 *     a detectable fingerprint (a swap of memset(dst, c, n) to memset(c, dst, n)
 *     writes to a tiny numeric "address" and will corrupt page 0 / crash
 *     rather than silently pass).
 *   - Pre-fills use hand-written loops so a broken memset cannot mask itself
 *     via the pre-fill step.
 *   - After memcpy, both dst (expected: src content) AND src (expected:
 *     unchanged) are verified, so swapping dst/src is detected either way.
 *   - memcmp sign/magnitude is checked, not just != 0.
 *   - Return values are checked (memset/memcpy must return dst).
 *
 * Exit codes are distinct per probe so a ntvcm failure identifies the
 * failing routine exactly. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char dst[256];
static char src[256];
static char ref[256];

static void hand_clear(char *p, int n)
{
    for (int i = 0; i < n; ++i) p[i] = (char)0xC7;  /* sentinel != 0 */
}

int main(void)
{
    /* === memset ===
     * Signature: void *memset(void *s, int c, size_t n)
     * Push order under __smallc: s, c, n (L-to-R).
     * If c and s swap, memset writes 'n' bytes of 's' (an address) to
     * memory starting at numeric address c (0xAB) -- hard crash. */

    hand_clear(dst, 256);
    if (memset(dst, 0xAB, 4) != dst) return 10;         /* return value */
    if (dst[0] != (char)0xAB || dst[3] != (char)0xAB)   /* filled */
        return 11;
    if (dst[4] != (char)0xC7)                            /* NOT overrun */
        return 12;

    hand_clear(dst, 256);
    memset(dst, 0x5A, 128);
    if (dst[0] != 0x5A || dst[127] != 0x5A)
        return 13;
    if (dst[128] != (char)0xC7)
        return 14;

    hand_clear(dst, 256);
    memset(dst, 0xFF, 256);
    for (int i = 0; i < 256; ++i)
        if (dst[i] != (char)0xFF) return 15;

    /* Variable-length memset: n not a compile-time constant */
    for (int n = 0; n <= 32; ++n) {
        hand_clear(dst, 256);
        memset(dst, 0x42, (size_t)n);
        for (int i = 0; i < n; ++i)
            if (dst[i] != 0x42) return 16;
        if (dst[n] != (char)0xC7)
            return 17;
    }

    /* === memcpy ===
     * Signature: void *memcpy(void *dst, const void *src, size_t n)
     * If dst and src swap, src gets overwritten with dst's content.
     * We check both dst (got src) AND src (unchanged). */

    for (int i = 0; i < 256; ++i)
        src[i] = (char)(0x80 ^ (i & 0x7F));              /* asymmetric pattern */
    for (int i = 0; i < 256; ++i)
        ref[i] = src[i];                                 /* independent snapshot */

    hand_clear(dst, 256);
    if (memcpy(dst, src, 4) != dst) return 20;
    for (int i = 0; i < 4; ++i)
        if (dst[i] != ref[i]) return 21;
    if (dst[4] != (char)0xC7) return 22;
    for (int i = 0; i < 256; ++i)                        /* src unchanged */
        if (src[i] != ref[i]) return 23;

    hand_clear(dst, 256);
    memcpy(dst, src, 128);
    for (int i = 0; i < 128; ++i)
        if (dst[i] != ref[i]) return 24;
    if (dst[128] != (char)0xC7) return 25;
    for (int i = 0; i < 256; ++i)
        if (src[i] != ref[i]) return 26;

    hand_clear(dst, 256);
    memcpy(dst, src, 256);
    for (int i = 0; i < 256; ++i)
        if (dst[i] != ref[i]) return 27;

    /* Variable-length memcpy */
    for (int n = 0; n <= 32; ++n) {
        hand_clear(dst, 256);
        memcpy(dst, src, (size_t)n);
        for (int i = 0; i < n; ++i)
            if (dst[i] != ref[i]) return 28;
        if (dst[n] != (char)0xC7) return 29;
    }

    /* === memmove ===
     * Signature: void *memmove(void *dst, const void *src, size_t n)
     * Must handle overlap correctly in both directions. */

    /* Forward-overlap: dst > src (copy backward internally) */
    for (int i = 0; i < 32; ++i) src[i] = (char)(i + 1);
    memmove(src + 4, src, 16);
    /* src = [1 2 3 4 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 ...] */
    if (src[0] != 1 || src[3] != 4) return 30;
    if (src[4] != 1 || src[19] != 16) return 31;
    if (src[20] != 21) return 32;

    /* Backward-overlap: dst < src (copy forward internally) */
    for (int i = 0; i < 32; ++i) src[i] = (char)(i + 1);
    memmove(src, src + 4, 16);
    /* src = [5 6 ... 20 17 18 19 20 21 ...] */
    if (src[0] != 5 || src[15] != 20) return 33;
    if (src[16] != 17) return 34;

    /* Non-overlap (equivalent to memcpy) */
    for (int i = 0; i < 32; ++i) ref[i] = (char)(0x40 | i);
    hand_clear(dst, 256);
    if (memmove(dst, ref, 32) != dst) return 35;
    for (int i = 0; i < 32; ++i)
        if (dst[i] != (char)(0x40 | i)) return 36;
    if (dst[32] != (char)0xC7) return 37;

    /* === memcmp ===
     * Signature: int memcmp(const void *s1, const void *s2, size_t n)
     * Result sign depends on first byte that differs: positive if
     * *s1 > *s2 (byte-wise unsigned), negative if *s1 < *s2.
     * If s1/s2 swap, the sign flips -- detectable. */

    for (int i = 0; i < 64; ++i) {
        dst[i] = (char)i;
        ref[i] = (char)i;
    }
    if (memcmp(dst, ref, 64) != 0) return 40;

    /* dst < ref at index 32 (dst=0x42, ref=0x63) → return negative */
    dst[32] = 0x42; ref[32] = 0x63;
    if (memcmp(dst, ref, 64) >= 0) return 41;
    /* Swap operands → positive */
    if (memcmp(ref, dst, 64) <= 0) return 42;

    /* First-byte differs (short-circuit test, exercises arg ordering) */
    dst[0] = 1; ref[0] = 2;
    if (memcmp(dst, ref, 64) >= 0) return 43;
    if (memcmp(ref, dst, 64) <= 0) return 44;

    /* Length 0: always equal regardless of content */
    if (memcmp(dst, ref, 0) != 0) return 45;

    /* Length 1, differing bytes */
    dst[0] = 5; ref[0] = 3;
    if (memcmp(dst, ref, 1) <= 0) return 46;

    printf("ALL PASS\n");
    return 0;
}
