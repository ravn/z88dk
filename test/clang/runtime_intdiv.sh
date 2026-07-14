#!/bin/sh
# Red-green runtime test covering EVERY routine in the libsrc/l/llvmz80/ integer
# runtime bridge (bridges to the shared l_* math cores).
#
# Which compiler-rt name the backend emits depends on the opt level and code
# shape, so this builds + runs runtime_intdiv.c at BOTH -O2 and -O2 --opt-code-size and, for
# each, (a) asserts the link resolved, (b) asserts the map references the
# bridge symbols that opt level is expected to emit (coverage proof), and
# (c) runs it in ntvcm and checks every computed value.
#
# GREEN: links + prints correct results at both opt levels.
# RED  : a missing bridge symbol -> "undefined symbol: ___...", or a wrong-ABI
#        bridge -> links but prints wrong numbers.  Both are caught below.
#        (Before the _fast + __divmodsi4/__udivmodsi4 bridges existed, the -O2
#        link failed on ___divhi3_fast / ___divmodsi4.)
#
# Usage: ZCCCFG=<z88dk>/lib/config PATH=<z88dk>/bin:$PATH \
#        NTVCM=/path/to/ntvcm ./runtime_intdiv.sh
# Requires zcc (llvmz80 configured) + an ntvcm CP/M emulator (env NTVCM, else
# `ntvcm` on PATH).  Skips (exit 0) if either is unavailable.
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
SRC="$DIR/runtime_intdiv.c"

command -v zcc >/dev/null 2>&1 || { echo "SKIP: zcc not on PATH"; exit 0; }
NTVCM=${NTVCM:-ntvcm}
command -v "$NTVCM" >/dev/null 2>&1 || { echo "SKIP: ntvcm not found (set NTVCM)"; exit 0; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $1"; exit 1; }

# Host-computed expectations (identical at every opt level):
#   16-bit: 1234*57=70338->4802; 1234/57=21; 1234%57=37;
#           50000*7=350000->22320; 50000/7=7142; 50000%7=6
#   32-bit: 1000000/7=142857 rem 1; 4000000000/13=307692307 rem 9
#   8-bit : 200/7=28; 200%7=4
EXP_H="h 4802 21 37 22320 7142 6"
EXP_L="l 142857 1 307692307 9"
EXP_F="f 142857 1 307692307 9"
EXP_Q="q 28 4"

# run_at <opt> <space-separated bridge symbols expected in the map>
run_at() {
	OPT="$1"; shift
	EXPECT_SYMS="$*"
	B="$WORK/rt_$(echo "$OPT" | tr -d ' -')"
	if ! zcc +cpm -compiler=llvmz80 $OPT -create-app -o "$B" "$SRC" -m >"$B.log" 2>&1; then
		echo "--- build log ($OPT) ---"; cat "$B.log"
		if grep -qi 'undefined symbol' "$B.log"; then
			fail "$OPT: link failed with undefined runtime helper (bridge symbol missing from z80_crt0.lib?)"
		fi
		fail "$OPT: zcc build failed"
	fi
	[ -f "$B.com" ] || fail "$OPT: no .com produced"

	# (b) coverage proof: the map must reference each expected bridge symbol.
	for sym in $EXPECT_SYMS; do
		grep -q "$sym" "$B.map" || fail "$OPT: expected bridge symbol $sym not referenced (coverage gap)"
	done

	# (c) value check.
	OUT=$("$NTVCM" "$B.com" 2>/dev/null | tr -d '\r')
	echo "$OUT" | grep -qF "$EXP_H" || fail "$OPT: 16-bit wrong. got: $(echo "$OUT" | sed -n 1p) want: $EXP_H"
	echo "$OUT" | grep -qF "$EXP_L" || fail "$OPT: 32-bit separate wrong. got: $(echo "$OUT" | sed -n 2p) want: $EXP_L"
	echo "$OUT" | grep -qF "$EXP_F" || fail "$OPT: 32-bit fused divmod wrong. got: $(echo "$OUT" | sed -n 3p) want: $EXP_F"
	echo "$OUT" | grep -qF "$EXP_Q" || fail "$OPT: 8-bit wrong. got: $(echo "$OUT" | sed -n 4p) want: $EXP_Q"
	echo "  ok $OPT (symbols: $EXPECT_SYMS)"
}

# -O2 (clang -O3): 16-bit uses the _fast cores; 32-bit uses fused divmod.
run_at "-O2" _divhi3_fast _udivhi3_fast _modhi3_fast _umodhi3_fast _mulhi3 _divmodsi4 _udivmodsi4 _divsi3 _modsi3 _udivsi3 _umodsi3
# -O2 --opt-code-size (clang -Oz): 16-bit uses the plain cores; the 8-bit qi
# cores appear (inlined at -O3); 32-bit still fused.  NB: -Os also maps to
# clang -O3, so --opt-code-size is the only way to reach the -Oz name set.
run_at "-O2 --opt-code-size" _divhi3 _udivhi3 _modhi3 _umodhi3 _mulhi3 _udivqi3 _umodqi3 _divmodsi4 _udivmodsi4 _divsi3 _modsi3 _udivsi3 _umodsi3

echo "PASS: llvmz80 integer runtime bridge (16/8/32-bit, fast + fused) links and computes correctly at -O2 and --opt-code-size"
