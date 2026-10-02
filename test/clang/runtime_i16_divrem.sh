#!/bin/sh
# Check native-core quotient/remainder values, not just emitted symbol names.
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
[ -f "$DIR/test_env.sh" ] && . "$DIR/test_env.sh"
command -v zcc >/dev/null 2>&1 || { echo "SKIP: zcc not on PATH"; exit 0; }
NTVCM=${NTVCM:-ntvcm}
command -v "$NTVCM" >/dev/null 2>&1 || { echo "SKIP: ntvcm not found"; exit 0; }
mkdir -p "$DIR/../../../scratch/tmp"
WORK=$(mktemp -d "$DIR/../../../scratch/tmp/i16-divrem.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
for opt in -O0 -O2 -O3 --opt-code-size; do
    if ! zcc +cpm -compiler=llvmz80 ${ZCC_CLIB:-} "$opt" -create-app \
        -o "$WORK/rt" "$DIR/runtime_i16_divrem.c" >"$WORK/build.log" 2>&1; then
        cat "$WORK/build.log"
        echo "FAIL: $opt build failed"
        exit 1
    fi
    OUT=$("$NTVCM" "$WORK/RT.COM" 2>/dev/null | tr -d '\r')
    for expected in \
        'separate=-4285,-5,7142,6' \
        'fused=-4285,-5,7142,6' \
        'negative-divisor=-4285,5' \
        'small-dividend=0,-6' \
        'boundary=255,255'; do
        if ! printf '%s\n' "$OUT" | grep -qxF "$expected"; then
            echo "FAIL: $opt got [$OUT], missing [$expected]"
            exit 1
        fi
    done
done
echo "PASS: native i16 division/remainder values at O0/O2/O3/Oz"
