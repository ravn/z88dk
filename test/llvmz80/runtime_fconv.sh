#!/bin/sh
# Runtime test for the z88dk-triple binary32 conversion lowering,
# ravn/llvm-z80 #277 (follow-up to runtime_float.c).
#
# The z88dk triple calls existing `cm32_sdcc_*` entries with
# `Z80_SDCCCall0`; `--math32` selects their runtime. This exercises signed and
# unsigned conversions in both directions, including boundary values.
#
# Usage: ZCCCFG=<z88dk>/lib/config PATH=<z88dk>/bin:$PATH \
#        NTVCM=/path/to/ntvcm LLVMZ80EXE=/path/to/clang ./runtime_fconv.sh
# Skips (exit 0) if neither the compiler nor the emulator is available.
set -e
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$DIR/test_env.sh"
SRC="$DIR/runtime_fconv.c"

command -v "$ZCC" >/dev/null 2>&1 || { echo "SKIP: zcc not found"; exit 0; }
command -v "$NTVCM" >/dev/null 2>&1 || { echo "SKIP: ntvcm not found (set NTVCM)"; exit 0; }

WORK=$(mktemp -d "$Z80_TEST_TMPDIR/llvmz80-fconv.XXXXXX")
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

echo "$OUT" | grep -qF "ALL PASS" || fail "conversion output wrong. got: [$OUT]"

echo "PASS: llvmz80 int<->f32 conversions use z88dk math32 correctly"
