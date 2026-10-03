#!/bin/sh
# Runtime test for the ravn/llvm-z80 f32 FAST-MATH compare lowering to
# z88dk math32. ravn/llvm-z80 #277 follow-up.
#
# GREEN: `zcc +cpm -compiler=llvmz80 -ffast-math` links a program using
#        every ordered float compare predicate (==,!=,<,<=,>,>=) against
#        the existing z88dk math32 library, and running it in ntvcm prints
#        "ALL PASS". NaN inputs are outside the current runtime-test policy.
#
# See runtime_fcmp.sh for the NaN-aware, non-fast-math sibling test and
# the shared Z88DK-triple / math32 library setup.
#
# Usage: ZCCCFG=<z88dk>/lib/config PATH=<z88dk>/bin:$PATH \
#        NTVCM=/path/to/ntvcm LLVMZ80EXE=/path/to/clang ./runtime_fcmp_fast.sh
# Skips (exit 0) if neither the compiler nor the emulator is available.
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
[ -f "$DIR/test_env.sh" ] && . "$DIR/test_env.sh"
SRC="$DIR/runtime_fcmp_fast.c"
command -v zcc >/dev/null 2>&1 || { echo "SKIP: zcc not on PATH"; exit 0; }
NTVCM=${NTVCM:-ntvcm}
command -v "$NTVCM" >/dev/null 2>&1 || { echo "SKIP: ntvcm not found (set NTVCM)"; exit 0; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $1"; exit 1; }

if ! zcc +cpm -compiler=llvmz80 ${ZCC_CLIB:-} -O2 -ffast-math -create-app -lm \
	-o "$WORK/rt" "$SRC" >"$WORK/build.log" 2>&1; then
	echo "--- build log ---"; cat "$WORK/build.log"
	fail "zcc build failed"
fi
[ -f "$WORK/RT.COM" ] || fail "no .com produced"

OUT=$("$NTVCM" "$WORK/RT.COM" 2>/dev/null | tr -d '\r')

echo "$OUT" | grep -qF "ALL PASS" || fail "fast-math compare output wrong. got: [$OUT]"

echo "PASS: llvmz80 f32 fast-math comparisons link to z88dk math32 and behave for finite values"
