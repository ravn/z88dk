#!/bin/sh
# Transparent IEEE-754 printf via the opt-in __LLVMZ80_IEEE_PRINTF header route.
#
# GREEN: STOCK printf/snprintf (no __llvmz80_ prefix), compiled with
#        -D__LLVMZ80_IEEE_PRINTF, produce correct IEEE %f (3.141593) + all
#        other specifiers.
# RED  : without the route, stock z88dk printf would format clang's IEEE double
#        as math48 garbage.
#
# Needs the softfloat runtime archive (LLVMZ80RTLIB) — a %f program links it
# anyway.  Skips if zcc/ntvcm/softfloat lib unavailable.
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
SRC="$DIR/runtime_printf_ieee.c"

command -v zcc >/dev/null 2>&1 || { echo "SKIP: zcc not on PATH"; exit 0; }
NTVCM=${NTVCM:-ntvcm}
command -v "$NTVCM" >/dev/null 2>&1 || { echo "SKIP: ntvcm not found (set NTVCM)"; exit 0; }
RTLIB="${LLVMZ80RTLIB:-/tmp/softfloat_lib/softfloat_cpm_z80}"
[ -f "$RTLIB.lib" ] || { echo "SKIP: softfloat lib not built ($RTLIB.lib)"; exit 0; }
export LLVMZ80RTLIB="$RTLIB"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $1"; exit 1; }

if ! zcc +cpm -compiler=llvmz80 -O2 -D__LLVMZ80_IEEE_PRINTF \
        -create-app -o "$WORK/rt" "$SRC" >"$WORK/build.log" 2>&1; then
    echo "--- build log ---"; cat "$WORK/build.log"
    fail "zcc build failed"
fi
[ -f "$WORK/rt.com" ] || fail "no .com produced"

OUT=$("$NTVCM" "$WORK/rt.com" 2>/dev/null | tr -d '\r')
echo "$OUT" | grep -qF "PASS ieee printf" \
    || fail "stock printf %f routing wrong. got: [$OUT]"

echo "PASS: stock printf(\"%f\") routes to nanoprintf via -D__LLVMZ80_IEEE_PRINTF"
