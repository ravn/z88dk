#!/bin/sh
# Regression guard for ravn/z88dk#22 (classic stdio fputs register-vs-stack ABI
# under -compiler=llvmz80). GREEN after the include/stdio.h __LLVMZ80 fix.
#
# Usage: ZCCCFG=<z88dk>/lib/config PATH=<z88dk>/bin:$PATH \
#        NTVCM=/path/to/ntvcm ./issue22_stdio_fputs.sh
# Skips (exit 0) if compiler or emulator is unavailable.
#
# macOS has no timeout(1) and the RED symptom is a warm-boot hang, so the run is
# wrapped in a perl alarm exec (10 s); a timeout counts as FAIL (regressed).
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
SRC="$DIR/issue22_stdio_fputs.c"

command -v zcc >/dev/null 2>&1 || { echo "SKIP: zcc not on PATH"; exit 0; }
NTVCM=${NTVCM:-ntvcm}
command -v "$NTVCM" >/dev/null 2>&1 || { echo "SKIP: ntvcm not found (set NTVCM)"; exit 0; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $1"; exit 1; }

zcc +cpm -compiler=llvmz80 --opt-code-size -create-app -o "$WORK/t" "$SRC" \
    >"$WORK/build.log" 2>&1 || { cat "$WORK/build.log"; fail "build failed"; }
[ -f "$WORK/t.com" ] || fail "no .com produced"

OUT=$(perl -e 'alarm shift; exec @ARGV' 10 "$NTVCM" "$WORK/t.com" 2>/dev/null \
        | tr -d '\r' | head -20)

echo "$OUT" | grep -q "DONE"    || fail "did not reach DONE (warm-boot loop? #22 regressed)"
echo "$OUT" | grep -q "^read=BC" || fail "readback wrong (got: $(echo "$OUT" | sed -n 's/^read=//p'))"
R=$(echo "$OUT" | sed -n 's/^fputs=//p' | head -1)
[ -n "$R" ] && [ "$R" != "-1" ] || fail "fputs returned $R (want > 0)"
echo "PASS: issue22_stdio_fputs (fputs=$R, read=BC)"
