#!/bin/sh
# Red-green runtime test for qsort with a clang/llvmz80 comparator.
#
# GREEN: a comparator declared __z88dk_callback is compiled to read
#        its two arguments from the stack and return the int result in HL --
#        exactly the protocol l_cmp_sdcc uses to invoke the comparator.
#        Fixed arrays sort in both directions before checking the LCG dataset.
# RED  : a DEFAULT (unannotated) comparator takes a in HL, b in DE and returns
#        in DE; qsort_sdcc feeds it stack args and reads HL -> the sort
#        scrambles the array instead of ordering it.
#
# This validates the z88dk maintainer's "annotate the callback" approach: no
# runtime trampoline or global state, fully reentrant.  See runtime_qsort.c.
#
# Usage: ZCCCFG=<z88dk>/lib/config PATH=<z88dk>/bin:$PATH \
#        NTVCM=/path/to/ntvcm ./runtime_qsort.sh
# Skips (exit 0) if the compiler or emulator is not available.
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
[ -f "$DIR/test_env.sh" ] && . "$DIR/test_env.sh"
SRC="$DIR/runtime_qsort.c"

command -v zcc >/dev/null 2>&1 || { echo "SKIP: zcc not on PATH"; exit 0; }
NTVCM=${NTVCM:-ntvcm}
command -v "$NTVCM" >/dev/null 2>&1 || { echo "SKIP: ntvcm not found (set NTVCM)"; exit 0; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $1"; exit 1; }

if ! zcc +cpm -compiler=llvmz80 ${ZCC_CLIB:-} -O1 -create-app \
	-o "$WORK/rt" "$SRC" >"$WORK/build.log" 2>&1; then
	echo "--- build log ---"; cat "$WORK/build.log"
	fail "zcc build failed"
fi
[ -f "$WORK/RT.COM" ] || fail "no .com produced"

OUT=$("$NTVCM" "$WORK/RT.COM" 2>/dev/null | tr -d '\r')

CALLBACK_EXP='callback asc=-3,0,1,7,7 desc=7,7,1,0,-3'
echo "$OUT" | grep -qxF "$CALLBACK_EXP" \
	|| fail "callback ABI/output wrong. got: [$OUT] want: [$CALLBACK_EXP]"
echo "  ok callback ABI (fixed data, both directions)"

EXP='qsort 200 5 991 OK'
echo "$OUT" | grep -qxF "$EXP" || fail "LCG dataset/output wrong. got: [$OUT] want: [$EXP]"

echo "PASS: llvmz80 qsort callback ABI and LCG dataset sort correctly"
