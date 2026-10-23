/* Emission-level test: verifies llvmz80 backend emits inline LDIR/LDDR
 * when direction is statically known, rather than calling asm_memmove.
 *
 * Companion to memops_backend_paths.c which tests behavioural correctness.
 * This file is NEVER linked / executed — only compiled to .s and grepped
 * by scripts/check_memops_emission.sh.
 *
 * IMPORTANT: this file INTENTIONALLY does not use <string.h>.
 * z88dk's <string.h> redirects memmove/memcpy/memset through ZPROTO macros
 * to `_memmove_callee` / `_memcpy_callee` / `_memset_callee` BEFORE the
 * backend sees them.  That means source-level calls via <string.h> never
 * get a chance to inline LDIR/LDDR — the backend only sees a function call.
 *
 * To test the backend's inline-LDIR/LDDR capability we must bypass the
 * ZPROTO macro.  We do this with `__builtin_memmove` / `__builtin_memcpy`
 * / `__builtin_memset`, which are compiler intrinsics clang recognises
 * directly without any header involvement.  The backend lowers them as
 * G_MEMMOVE/G_MEMCPY/G_MEMSET and gets to pick inline emission vs. a
 * runtime call based on direction/size/alignment.
 *
 * Aggregate struct copy (`*d = *s`) ALSO goes through the backend
 * (not through ZPROTO) because it is a C-language-level aggregate op,
 * not a memcpy call — so inline LDIR is expected there too. */

static char buf[256];
/* volatile prevents dead-store elimination of memcpy test (dst never read) */
static volatile char dst[128];
static char src[128];

/* === Inline-LDDR cases (dst > src: known forward overlap) === */

/* FN emit_lddr_fixed_offset:
 * memmove(buf+8, buf, 32) — constant offset, dst > src → LDDR inline. */
void emit_lddr_fixed_offset(void)
{
    __builtin_memmove(buf + 8, buf, 32);
}

/* === Inline-LDIR cases (dst < src: known backward overlap) === */

/* FN emit_ldir_fixed_offset:
 * memmove(buf, buf+8, 32) — constant offset, dst < src → LDIR inline. */
void emit_ldir_fixed_offset(void)
{
    __builtin_memmove(buf, buf + 8, 32);
}

/* FN emit_ldir_memcpy_const:
 * memcpy with constant size — always LDIR inline (memcpy semantics
 * forbid overlap so direction choice is trivial).
 * Buffers come in via args to prevent dead-store elimination. */
void emit_ldir_memcpy_const(char *d, const char *s)
{
    __builtin_memcpy(d, s, 64);
}

/* FN emit_ldir_aggregate_copy:
 * *d = *s struct copy — backend G_MEMCPY lowering goes to LDIR inline. */
typedef struct { char data[128]; } Big;
/* Two-arg function: default sdcccall(0) already puts first ptr in HL,
 * second arrives on stack.  __attribute__((z88dk_fastcall)) only supports a single arg. */
void emit_ldir_aggregate_copy(Big *d, const Big *s)
{
    *d = *s;
}

/* === Must-call-asm_memmove cases (direction unknown at compile time) === */

/* FN emit_call_memmove_var:
 * memmove with runtime pointers — direction unknown → must call asm_memmove.
 * This is the negative control: inline LDIR/LDDR must NOT appear here. */
void emit_call_memmove_var(char *a, char *b, unsigned n)
{
    __builtin_memmove(a, b, n);
}

/* === asm_memset cases (backend-synthesized, any size) === */

/* FN emit_call_asm_memset_zero:
 * Zero-init of large struct via compound literal → asm_memset call. */
void emit_call_asm_memset_zero(Big *p) __attribute__((z88dk_fastcall));
void emit_call_asm_memset_zero(Big *p)
{
    Big empty = {0};
    *p = empty;
}

/* FN emit_call_asm_memset_loop:
 * Loop-idiom-recognizer → asm_memset.  Uses 16-bit counter. */
void emit_call_asm_memset_loop(char *p, unsigned n)
{
    for (unsigned i = 0; i < n; ++i) p[i] = (char)0xFF;
}

/* FN emit_call_asm_memset_loop_u8:
 * 8-bit counter loop — future DJNZ-candidate, currently also lowers via
 * memset-idiom to asm_memset.  Pattern must stay stable: either DJNZ
 * (dec b / jr nz) or asm_memset, never both. */
void emit_call_asm_memset_loop_u8(char *p, unsigned char n)
{
    for (unsigned char i = 0; i < n; ++i) p[i] = (char)0x44;
}
