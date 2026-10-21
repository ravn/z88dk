/* Runtime testsuite: <string.h> entries via ZPROTO __z88dk_callee thunks.
 *
 * Exercises the compiler-generated calls to:
 *   _strcpy_callee, _strncpy_callee, _strcat_callee
 *   _strcmp_callee, _strncmp_callee
 *   _strlen_callee
 *   _strchr_callee, _strrchr_callee
 *
 * All of these are ZPROTO __z88dk_callee thunks defined in <string.h> via
 * include/sys/compiler.h -- the macros re-route standard-C names to the
 * sccz80 classic-library bare entries whose L-to-R push order matches
 * llvmz80's __smallc.  This is the primary ABI surface PR #90 wires up.
 *
 * Hardening against ABI parameter-order bugs:
 *   - strcpy(dst, src): if dst/src swap, src gets written and dst stays
 *     the sentinel.  We check BOTH ends (dst content == src content AND
 *     dst != pre-fill sentinel).
 *   - strcmp(a, b): symmetric semantics means swap must flip sign.
 *     Both orders exercised explicitly.
 *   - strncpy with n < strlen(src) and n > strlen(src) exercises both
 *     truncation and NUL-padding behaviours.
 *   - strchr found/not-found verifies pointer-return path.
 *   - Buffers in volatile-adjacent BSS so compiler can't fold at compile
 *     time; string literals used as sources force runtime path.
 *
 * Exit codes are distinct per probe. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char dst[64];
static char buf[64];

static void sentinel_fill(char *p, int n)
{
    for (int i = 0; i < n; ++i) p[i] = (char)0xC7;
}

int main(void)
{
    /* === strcpy === */

    sentinel_fill(dst, 64);
    if (strcpy(dst, "hello") != dst) return 10;    /* return value */
    if (dst[0] != 'h' || dst[4] != 'o' || dst[5] != 0)
        return 11;
    if (dst[6] != (char)0xC7)                       /* no overrun */
        return 12;

    /* Long string */
    sentinel_fill(dst, 64);
    strcpy(dst, "the quick brown fox jumps over the lazy dog");
    if (dst[0] != 't' || dst[42] != 'g' || dst[43] != 0)
        return 13;
    if (dst[44] != (char)0xC7)
        return 14;

    /* Empty string */
    sentinel_fill(dst, 64);
    strcpy(dst, "");
    if (dst[0] != 0 || dst[1] != (char)0xC7)
        return 15;

    /* === strncpy === */

    /* n < strlen(src): truncation, no NUL terminator written */
    sentinel_fill(dst, 64);
    if (strncpy(dst, "hello world", 5) != dst) return 20;
    if (dst[0] != 'h' || dst[4] != 'o')
        return 21;
    if (dst[5] != (char)0xC7)                       /* no auto-NUL */
        return 22;

    /* n > strlen(src): copy including NUL, then pad with NULs up to n */
    sentinel_fill(dst, 64);
    strncpy(dst, "hi", 8);
    if (dst[0] != 'h' || dst[1] != 'i' || dst[2] != 0)
        return 23;
    for (int i = 3; i < 8; ++i)
        if (dst[i] != 0) return 24;
    if (dst[8] != (char)0xC7)                       /* no overrun */
        return 25;

    /* n == strlen(src) exactly */
    sentinel_fill(dst, 64);
    strncpy(dst, "abc", 3);
    if (dst[0] != 'a' || dst[1] != 'b' || dst[2] != 'c')
        return 26;
    if (dst[3] != (char)0xC7)
        return 27;

    /* === strlen === */

    if (strlen("") != 0) return 30;
    if (strlen("x") != 1) return 31;
    if (strlen("hello") != 5) return 32;
    if (strlen("the quick brown fox") != 19) return 33;

    /* strlen on buffer where NUL is at known offset */
    sentinel_fill(buf, 64);
    buf[0] = 'a'; buf[1] = 'b'; buf[2] = 'c'; buf[3] = 0;
    if (strlen(buf) != 3) return 34;

    /* === strcmp ===
     * Must detect sign flip under operand swap (symmetric semantics). */

    if (strcmp("", "") != 0) return 40;
    if (strcmp("abc", "abc") != 0) return 41;

    /* lt */
    if (strcmp("abc", "abd") >= 0) return 42;
    /* gt via swap */
    if (strcmp("abd", "abc") <= 0) return 43;

    /* prefix: shorter < longer */
    if (strcmp("abc", "abcd") >= 0) return 44;
    if (strcmp("abcd", "abc") <= 0) return 45;

    /* First-byte differs */
    if (strcmp("a", "b") >= 0) return 46;
    if (strcmp("b", "a") <= 0) return 47;

    /* === strncmp === */

    if (strncmp("abc", "abc", 3) != 0) return 50;
    if (strncmp("abc", "abd", 3) >= 0) return 51;
    if (strncmp("abd", "abc", 3) <= 0) return 52;

    /* Prefix match within n */
    if (strncmp("abcdef", "abcxyz", 3) != 0) return 53;

    /* n==0: always equal */
    if (strncmp("abc", "xyz", 0) != 0) return 54;

    /* n > strlen stops at NUL */
    if (strncmp("ab", "ab", 100) != 0) return 55;

    /* === strcat === */

    sentinel_fill(dst, 64);
    strcpy(dst, "hello");
    if (strcat(dst, " world") != dst) return 60;
    if (strcmp(dst, "hello world") != 0) return 61;
    if (dst[11] != 0 || dst[12] != (char)0xC7)
        return 62;

    /* Appending empty string */
    sentinel_fill(dst, 64);
    strcpy(dst, "abc");
    strcat(dst, "");
    if (strcmp(dst, "abc") != 0) return 63;

    /* === strchr === */

    char *p = strchr("hello", 'l');
    if (p == NULL || *p != 'l') return 70;

    p = strchr("hello", 'o');
    if (p == NULL || *p != 'o' || *(p + 1) != 0)
        return 71;

    /* Not found returns NULL */
    if (strchr("hello", 'z') != NULL) return 72;

    /* strchr finds NUL at end */
    p = strchr("hi", 0);
    if (p == NULL || *p != 0) return 73;

    /* strchr first char */
    p = strchr("hello", 'h');
    if (p == NULL || *p != 'h') return 74;

    /* === strrchr === */

    p = strrchr("hello", 'l');
    if (p == NULL || *p != 'l' || *(p + 1) != 'o')
        return 80;

    /* Only occurrence */
    p = strrchr("abc", 'b');
    if (p == NULL || *p != 'b') return 81;

    /* Not found */
    if (strrchr("hello", 'z') != NULL) return 82;

    printf("ALL PASS\n");
    return 0;
}
