#!/bin/sh
# Regression test for ravn/z88dk#83:
# sdcc_peeph.3 peephole 149a/149b must not remove jp to EXTERN callee symbols.
#
# GREEN: compiling a switch-on-memcpy function with -SO3 still produces
#        jp _memcpy_callee in the assembly output for every case arm.
# RED  : one or more jp _memcpy_callee are missing (eaten by 149a/149b).
#
# Usage: PATH=<z88dk>/bin:$PATH ZCCCFG=<z88dk>/lib/config ./issue83_memcpy_callee_peeph.sh
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
[ -f "$DIR/test_env.sh" ] && . "$DIR/test_env.sh"

command -v zcc >/dev/null 2>&1 || { echo "SKIP: zcc not on PATH"; exit 0; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $1"; exit 1; }

# A 4-case switch where every arm ends with memcpy — this is the pattern that
# triggers peephole 149b after case-tail-call collapse (peep 84+149): each
# case body ends with "jp l_copy_n_NNNN" and the case dispatch also uses
# "jp l_copy_n_NNNN", so after 149 collapses them the second jp becomes orphan.
cat > "$WORK/t.c" << 'CSRC'
#include <string.h>
extern unsigned char src[8], dst[8];
void copy_n(unsigned char mode) {
    switch (mode) {
    case 0: memcpy(dst, src, 1); break;
    case 1: memcpy(dst, src, 2); break;
    case 2: memcpy(dst, src, 4); break;
    default: memcpy(dst, src, 8); break;
    }
}
CSRC

# Compile with sdcc peephole level 3 (-SO3), extract assembly
zcc +cpm -compiler=sdcc -SO3 -S -o "$WORK/t.asm" "$WORK/t.c" \
    >"$WORK/build.log" 2>&1 \
    || { echo "--- build log ---"; cat "$WORK/build.log"; fail "compilation failed"; }

# Count jp/call instructions that reach _memcpy_callee in copy_n.
# With 4 cases and one default, we expect at least 4 references.
COUNT=$(grep -cE "(jp|call).*_memcpy_callee" "$WORK/t.asm" || true)
[ "$COUNT" -ge 4 ] \
    || fail "expected >=4 jp/call to _memcpy_callee in 4-case switch, got $COUNT (peephole 149a/149b may have removed some)"

echo "PASS: all $COUNT jp/call _memcpy_callee present after -SO3 peephole (149a/149b did not over-remove)"
