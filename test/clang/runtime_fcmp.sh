#!/bin/sh
# Runtime test for the ravn/llvm-z80 f32 compare lowering to z88dk math32.
# ravn/llvm-z80 #277.
#
# NaNs are outside the current runtime-test policy; runtime_fcmp.c covers
# finite values only. A wrong native-symbol mapping/result fails a chk().
#
# See runtime_float.sh for the shared -mllvm -z80-float-sdcccall0 / -lmath32
# requirement story (identical here).
#
# Usage: ZCCCFG=<z88dk>/lib/config PATH=<z88dk>/bin:$PATH \
#        NTVCM=/path/to/ntvcm LLVMZ80EXE=/path/to/clang ./runtime_fcmp.sh
# Skips (exit 0) if neither the compiler nor the emulator is available.
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
[ -f "$DIR/test_env.sh" ] && . "$DIR/test_env.sh"
SRC="$DIR/runtime_fcmp.c"
command -v zcc >/dev/null 2>&1 || { echo "SKIP: zcc not on PATH"; exit 0; }
NTVCM=${NTVCM:-ntvcm}
command -v "$NTVCM" >/dev/null 2>&1 || { echo "SKIP: ntvcm not found (set NTVCM)"; exit 0; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $1"; exit 1; }

if ! zcc +cpm -compiler=llvmz80 ${ZCC_CLIB:-} -O2 -create-app -lm \
	-o "$WORK/rt" "$SRC" >"$WORK/build.log" 2>&1; then
	echo "--- build log ---"; cat "$WORK/build.log"
	fail "zcc build failed"
fi
[ -f "$WORK/RT.COM" ] || fail "no .com produced"

OUT=$("$NTVCM" "$WORK/RT.COM" 2>/dev/null | tr -d '\r')

echo "$OUT" | grep -qF "ALL PASS" || fail "compare output wrong. got: [$OUT]"

echo "PASS: llvmz80 f32 comparisons link to z88dk math32 and behave for finite values"
