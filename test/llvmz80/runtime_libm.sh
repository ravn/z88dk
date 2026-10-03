#!/bin/sh
# Runtime test for libm entry points provided by z88dk math32.
#
# zcc selects the math32 declarations for this target, and `--math32` selects
# their runtime. Calls use the declared z88dk entry points directly; this test
# does not depend on llvmz80-specific bridge files or flags.
#
# Usage: ZCCCFG=<z88dk>/lib/config PATH=<z88dk>/bin:$PATH \
#        NTVCM=/path/to/ntvcm ./runtime_libm.sh
# Skips (exit 0) if neither the compiler nor the emulator is available.
set -e
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$DIR/test_env.sh"
SRC="$DIR/runtime_libm.c"

command -v "$ZCC" >/dev/null 2>&1 || { echo "SKIP: zcc not found"; exit 0; }
command -v "$NTVCM" >/dev/null 2>&1 || { echo "SKIP: ntvcm not found (set NTVCM)"; exit 0; }

WORK=$(mktemp -d "$Z80_TEST_TMPDIR/llvmz80-libm.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir "$WORK/tmp"
fail() { echo "FAIL: $1"; exit 1; }

if ! TMPDIR="$WORK/tmp" "$ZCC" +cpm -compiler=llvmz80 ${ZCC_CLIB:-} -Cg-O3 -create-app --math32 \
	-o "$WORK/rt" "$SRC" >"$WORK/build.log" 2>&1; then
	echo "--- build log ---"; cat "$WORK/build.log"
	fail "zcc build failed"
fi
[ -f "$WORK/RT.COM" ] || fail "no .com produced"

OUT=$(TMPDIR="$WORK/tmp" "$NTVCM" "$WORK/RT.COM" 2>/dev/null | tr -d '\r')

echo "$OUT" | grep -qF "ALL PASS" || fail "libm output wrong. got: [$OUT]"

echo "PASS: llvmz80 exp/log/sin/cos/atan use z88dk math32 correctly"
