#!/bin/sh
# Runtime test for the ravn/llvm-z80 f32 compare lowering to z88dk math32.
# ravn/llvm-z80 #277.
#
# runtime_fcmp.c covers finite controls and NaN inputs in either position.
#
# The Z88DK triple selects existing math32 entries; --math32 links math32.
#
# Usage: ZCCCFG=<z88dk>/lib/config PATH=<z88dk>/bin:$PATH \
#        NTVCM=/path/to/ntvcm LLVMZ80EXE=/path/to/clang ./runtime_fcmp.sh
# Skips (exit 0) if neither the compiler nor the emulator is available.
set -e
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$DIR/test_env.sh"
SRC="$DIR/runtime_fcmp.c"
command -v "$ZCC" >/dev/null 2>&1 || { echo "SKIP: zcc not found"; exit 0; }
command -v "$NTVCM" >/dev/null 2>&1 || { echo "SKIP: ntvcm not found (set NTVCM)"; exit 0; }

WORK=$(mktemp -d "$Z80_TEST_TMPDIR/llvmz80-fcmp.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir "$WORK/tmp"

fail() { echo "FAIL: $1"; exit 1; }

if ! TMPDIR="$WORK/tmp" "$ZCC" +cpm -compiler=llvmz80 ${ZCC_CLIB:-} -Cg-O2 -create-app --math32 \
	-o "$WORK/rt" "$SRC" >"$WORK/build.log" 2>&1; then
	echo "--- build log ---"; cat "$WORK/build.log"
	fail "zcc build failed"
fi
[ -f "$WORK/RT.COM" ] || fail "no .com produced"

OUT=$(TMPDIR="$WORK/tmp" "$NTVCM" "$WORK/RT.COM" 2>/dev/null | tr -d '\r')

echo "$OUT" | grep -qF "ALL PASS" || fail "compare output wrong. got: [$OUT]"

echo "PASS: llvmz80 f32 comparisons link to z88dk math32 and preserve NaN semantics"
