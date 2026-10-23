/* Runtime testsuite: both memory-op emission paths llvmz80 backend uses.
 *
 * Two distinct paths exist for memset/memcpy/memmove on llvmz80 +cpm:
 *
 *   PATH 1 (source-level call): C-code `memset(...)` goes through <string.h>'s
 *     ZPROTO macro and becomes a direct `call _memset_callee` (callee-cleanup
 *     L-to-R push ABI, defined in cpm_clib.lib).  Backend never sees a
 *     G_MEMSET/G_MEMCPY intrinsic for these.
 *
 *   PATH 2 (backend-synthesized): aggregate struct copies, zero-init of large
 *     structs/arrays, and loops that LLVM's loop-idiom recognizer rewrites
 *     into memset lower to G_MEMSET/G_MEMCPY in GlobalISel.  On
 *     z80-unknown-none-z88dk these call `asm_memset` / `asm_memmove` with
 *     HL/DE/BC register ABI (defined in every crt0.lib — z80_crt0 and
 *     z80iy_crt0 both ship it).  memcpy is always inlined to LDIR regardless
 *     because non-overlap semantics make direction choice trivial.
 *
 * This test exercises both paths behaviourally and asserts the C-level
 * contract is preserved regardless of which path the backend picks.
 *
 * Hardening (same discipline as runtime_memory.c):
 *   - Hand-filled sentinels so a broken memset cannot mask itself.
 *   - Asymmetric fill values and sizes so swap of operands is detectable.
 *   - Trailing-byte-not-overwritten checks pin exact length.
 *   - Both source and dest content verified after copy.
 *
 * Exit codes are distinct per probe. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { char data[200]; } Big;

static char sentinel_buf[256];
static Big big_src, big_dst;
static Big big_a, big_b;

/* === Register-ABI variants (parameters arrive in registers) ===
 *
 * __z88dk_fastcall: single 16-bit argument arrives in HL (not on stack).
 * Combined with the backend's sdcccall(0) default for internal statics,
 * this exercises the backend's ABI shuffle from caller-register-HL to the
 * G_MEMSET/G_MEMCPY lowering's required register layout (HL=dst for both
 * asm_memset and asm_memmove). */

static void zero_a_big_hl(Big *p) __z88dk_fastcall;
static void zero_a_big_hl(Big *p)
{
    Big empty = {0};
    *p = empty;
}

static void loop_fill_hl(char *p) __z88dk_fastcall;
static void loop_fill_hl(char *p)
{
    /* n and v are compile-time constants so only the pointer travels via HL */
    for (unsigned i = 0; i < 64; ++i) p[i] = (char)0x5A;
}

static void sentinel_fill(char *p, int n)
{
    for (int i = 0; i < n; ++i) p[i] = (char)0xC7;
}

/* PATH 2 trigger: zero-init of large struct via compound literal.
 * Backend-synthesized G_MEMSET → asm_memset (native-runtime branch) or
 * ___z80_memset_builtin (old backend). */
static void zero_a_big(Big *p)
{
    Big empty = {0};
    *p = empty;
}

/* PATH 2 trigger: aggregate struct copy.  Backend-synthesized G_MEMCPY,
 * typically inlined to LDIR. */
static void copy_a_big(Big *dst, const Big *src)
{
    *dst = *src;
}

/* PATH 2 trigger: loop-idiom-recognizer rewrites to memset.
 * 16-bit counter — n up to 65535. */
static void loop_fill(char *p, unsigned n, char v)
{
    for (unsigned i = 0; i < n; ++i) p[i] = v;
}

/* PATH 2 trigger: same loop but with an 8-bit counter.
 * Future-work: the backend should recognise this as a DJNZ candidate
 * (B register count-down loop) rather than or in addition to
 * memset-idiom.  Today llvmz80 may lower it either way; the behavioural
 * contract is identical either way. */
static void loop_fill_u8(char *p, unsigned char n, char v)
{
    for (unsigned char i = 0; i < n; ++i) p[i] = v;
}

int main(void)
{
    /* === PATH 1: explicit <string.h> calls === */

    sentinel_fill(sentinel_buf, 256);
    if (memset(sentinel_buf, 0x5A, 32) != sentinel_buf) return 10;
    if (sentinel_buf[0] != 0x5A || sentinel_buf[31] != 0x5A) return 11;
    if (sentinel_buf[32] != (char)0xC7) return 12;    /* no overrun */

    sentinel_fill(sentinel_buf, 256);
    memcpy(sentinel_buf, "hello world", 11);
    if (sentinel_buf[0] != 'h' || sentinel_buf[10] != 'd') return 13;
    if (sentinel_buf[11] != (char)0xC7) return 14;

    /* === PATH 2: struct zero-init (compound literal) === */

    /* Seed big_dst with sentinel so a failed zero-init is visible. */
    for (int i = 0; i < 200; ++i) big_dst.data[i] = (char)0xC7;
    zero_a_big(&big_dst);
    for (int i = 0; i < 200; ++i)
        if (big_dst.data[i] != 0) return 20;

    /* === PATH 2: aggregate struct copy === */

    /* Asymmetric pattern so a swap of src/dst is detectable. */
    for (int i = 0; i < 200; ++i)
        big_src.data[i] = (char)(0x80 ^ (i & 0x7F));
    for (int i = 0; i < 200; ++i)
        big_dst.data[i] = (char)0xC7;              /* sentinel */
    copy_a_big(&big_dst, &big_src);
    for (int i = 0; i < 200; ++i)
        if (big_dst.data[i] != big_src.data[i]) return 30;
    /* Source must be unchanged */
    for (int i = 0; i < 200; ++i)
        if (big_src.data[i] != (char)(0x80 ^ (i & 0x7F))) return 31;

    /* === PATH 2: loop-idiom memset === */

    sentinel_fill(sentinel_buf, 256);
    loop_fill(sentinel_buf, 128, 0x33);
    for (int i = 0; i < 128; ++i)
        if (sentinel_buf[i] != 0x33) return 40;
    if (sentinel_buf[128] != (char)0xC7) return 41;   /* no overrun */

    /* n==0 edge: loop body never runs, buffer unchanged */
    sentinel_fill(sentinel_buf, 256);
    loop_fill(sentinel_buf, 0, 0x77);
    if (sentinel_buf[0] != (char)0xC7) return 42;

    /* === PATH 2: 8-bit counter loop (future DJNZ candidate) === */

    sentinel_fill(sentinel_buf, 256);
    loop_fill_u8(sentinel_buf, 100, 0x44);
    for (int i = 0; i < 100; ++i)
        if (sentinel_buf[i] != 0x44) return 43;
    if (sentinel_buf[100] != (char)0xC7) return 44;    /* no overrun */

    /* 8-bit max (255) boundary */
    sentinel_fill(sentinel_buf, 256);
    loop_fill_u8(sentinel_buf, 255, 0x55);
    for (int i = 0; i < 255; ++i)
        if (sentinel_buf[i] != 0x55) return 45;
    if (sentinel_buf[255] != (char)0xC7) return 46;

    /* n==0 edge for u8 counter */
    sentinel_fill(sentinel_buf, 256);
    loop_fill_u8(sentinel_buf, 0, 0x66);
    if (sentinel_buf[0] != (char)0xC7) return 47;

    /* === Register-ABI probes (fastcall: pointer arrives in HL) === */

    /* zero_a_big_hl: Big* arrives in HL, triggers G_MEMSET lowering.
     * Verifies backend's register-shuffle from HL input to asm_memset's
     * HL=dst, DE=0, BC=200 call ABI. */
    for (int i = 0; i < 200; ++i) big_a.data[i] = (char)0xC7;
    zero_a_big_hl(&big_a);
    for (int i = 0; i < 200; ++i)
        if (big_a.data[i] != 0) return 60;

    /* loop_fill_hl: char* arrives in HL, loop-idiom recognition triggers
     * G_MEMSET lowering with constant n=64 and v=0x5A. */
    sentinel_fill(sentinel_buf, 256);
    loop_fill_hl(sentinel_buf);
    for (int i = 0; i < 64; ++i)
        if (sentinel_buf[i] != 0x5A) return 61;
    if (sentinel_buf[64] != (char)0xC7) return 62;

    /* === Mixed: explicit memmove with runtime-direction === */

    /* Fill with distinct pattern so direction bug is visible. */
    for (int i = 0; i < 64; ++i) sentinel_buf[i] = (char)(i + 1);
    memmove(sentinel_buf + 8, sentinel_buf, 32);
    /* First 8 bytes unchanged, next 32 == original [0..31] */
    for (int i = 0; i < 8; ++i)
        if (sentinel_buf[i] != (char)(i + 1)) return 50;
    for (int i = 0; i < 32; ++i)
        if (sentinel_buf[i + 8] != (char)(i + 1)) return 51;
    if (sentinel_buf[40] != (char)41) return 52;      /* unchanged tail */

    /* Opposite overlap */
    for (int i = 0; i < 64; ++i) sentinel_buf[i] = (char)(i + 1);
    memmove(sentinel_buf, sentinel_buf + 8, 32);
    for (int i = 0; i < 32; ++i)
        if (sentinel_buf[i] != (char)(i + 9)) return 53;
    if (sentinel_buf[32] != (char)33) return 54;      /* unchanged tail */

    printf("ALL PASS\n");
    return 0;
}
