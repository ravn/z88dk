#!/bin/sh
# Runtime test for z88dk-triple binary32 arithmetic lowering,
# ravn/llvm-z80 #277.
#
# The z88dk triple lowers arithmetic to its existing `cm32_sdcc_*` math32
# entries with `Z80_SDCCCall0`. `--math32` selects the matching runtime;
# no llvmz80-specific bridge archive or ABI flag is involved.
#
# Usage: ZCCCFG=<z88dk>/lib/config PATH=<z88dk>/bin:$PATH \
#        NTVCM=/path/to/ntvcm ./runtime_float.sh
# Skips (exit 0) if neither the compiler nor the emulator is available.
set -e
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$DIR/test_env.sh"
SRC="$DIR/runtime_float.c"

command -v "$ZCC" >/dev/null 2>&1 || { echo "SKIP: zcc not found"; exit 0; }
command -v "$NTVCM" >/dev/null 2>&1 || { echo "SKIP: ntvcm not found (set NTVCM)"; exit 0; }

WORK=$(mktemp -d "$Z80_TEST_TMPDIR/llvmz80-float.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir "$WORK/tmp"
cd "$WORK"

fail() { echo "FAIL: $1"; exit 1; }

if ! TMPDIR="$WORK/tmp" "$ZCC" +cpm -compiler=llvmz80 ${ZCC_CLIB:-} -Cg-O2 -create-app --math32 \
	-o "$WORK/rt" "$SRC" >"$WORK/build.log" 2>&1; then
	echo "--- build log ---"; cat "$WORK/build.log"
	fail "zcc build failed"
fi
[ -f "$WORK/RT.COM" ] || fail "no .com produced"

if ! OUT=$(TMPDIR="$WORK/tmp" "$NTVCM" "$WORK/RT.COM" 2>"$WORK/run.log"); then
	cat "$WORK/run.log"
	fail "ntvcm run failed"
fi
OUT=$(printf '%s\n' "$OUT" | tr -d '\r')

echo "$OUT" | grep -qF "ALL PASS" || fail "float output wrong. got: [$OUT]"

echo "PASS: llvmz80 f32 add/sub/mul/div use z88dk math32 correctly"
