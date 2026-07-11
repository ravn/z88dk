#!/bin/sh
# Red-green runtime test for the ravn/llvm-z80 integer runtime helpers wired
# into z88dk via libsrc/l/llvmz80/ (bridges to the shared l_* math cores).
#
# GREEN: `zcc +cpm -compiler=llvmz80` links a program that does non-constant
#        16- and 32-bit multiply/divide/modulo (the backend emits
#        __mulhi3/__divhi3/... and __divsi3/__modsi3/...), and running it in
#        ntvcm prints the correct results.
# RED  : before libsrc/l/llvmz80/ existed, the link failed with
#        "undefined symbol: ___mulhi3"; a wrong-ABI bridge would link but print
#        wrong numbers.  Both failure modes are caught below.
#
# Usage: ZCCCFG=<z88dk>/lib/config PATH=<z88dk>/bin:$PATH \
#        NTVCM=/path/to/ntvcm ./runtime_intdiv.sh
# Requires: zcc on PATH (with the llvmz80 compiler configured) and an ntvcm
# CP/M emulator (env NTVCM, else `ntvcm` on PATH).  Skips (exit 0) if neither
# the compiler nor the emulator is available, so it is a no-op in environments
# that cannot run it.
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
SRC="$DIR/runtime_intdiv.c"

command -v zcc >/dev/null 2>&1 || { echo "SKIP: zcc not on PATH"; exit 0; }
NTVCM=${NTVCM:-ntvcm}
command -v "$NTVCM" >/dev/null 2>&1 || { echo "SKIP: ntvcm not found (set NTVCM)"; exit 0; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $1"; exit 1; }

# --- build (GREEN link) ---
if ! zcc +cpm -compiler=llvmz80 -O2 -create-app -o "$WORK/rt" "$SRC" >"$WORK/build.log" 2>&1; then
	echo "--- build log ---"; cat "$WORK/build.log"
	if grep -qi 'undefined symbol' "$WORK/build.log"; then
		fail "link failed with undefined runtime helper (libsrc/l/llvmz80 not wired into z80_crt0.lib?)"
	fi
	fail "zcc build failed"
fi
[ -f "$WORK/rt.com" ] || fail "no .com produced"

# --- run + check (GREEN values) ---
OUT=$("$NTVCM" "$WORK/rt.com" 2>/dev/null | tr -d '\r')

# Host-computed expectations:
#   16-bit: 1234*57=70338 -> 4802 (mod 2^16); 1234/57=21; 1234%57=37;
#           50000*7=350000 -> 22320 (mod 2^16); 50000/7=7142; 50000%7=6
#   32-bit: 1000000/7=142857; 1000000%7=1;
#           4000000000/13=307692307; 4000000000%13=9
EXP_H="h 4802 21 37 22320 7142 6"
EXP_L="l 142857 1 307692307 9"

echo "$OUT" | grep -qF "$EXP_H" || fail "16-bit helper output wrong. got: $(echo "$OUT" | sed -n 1p) want: $EXP_H"
echo "$OUT" | grep -qF "$EXP_L" || fail "32-bit helper output wrong. got: $(echo "$OUT" | sed -n 2p) want: $EXP_L"

echo "PASS: llvmz80 16- and 32-bit integer runtime helpers link and compute correctly"
