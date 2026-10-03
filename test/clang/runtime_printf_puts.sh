#!/bin/sh
# LLVM-Z80 only: retain printf despite an otherwise foldable format.
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/test_env.sh"
command -v zcc >/dev/null 2>&1 || { echo "SKIP: zcc not on PATH"; exit 0; }
NTVCM=${NTVCM:-ntvcm}
command -v "$NTVCM" >/dev/null 2>&1 || { echo "SKIP: ntvcm not found"; exit 0; }
mkdir -p "$DIR/../../../scratch/tmp"
WORK=$(mktemp -d "$DIR/../../../scratch/tmp/printf-puts.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

for opt in -O2 -O3 --opt-code-size; do
    if ! zcc +cpm -compiler=llvmz80 ${ZCC_CLIB:-} "$opt" -S \
        -o "$WORK/rt.s" "$DIR/runtime_printf_puts.c" >"$WORK/build.log" 2>&1; then
        cat "$WORK/build.log"
        echo "FAIL: $opt assembly build"
        exit 1
    fi
    puts_calls=$(grep -Ec '^[[:space:]]*(call|jp)[[:space:]]+_puts([[:space:]]|$)' "$WORK/rt.s" || true)
    printf_calls=$(grep -Ec '^[[:space:]]*(call|jp)[[:space:]]+_printf([[:space:]]|$)' "$WORK/rt.s" || true)
    if [ "$puts_calls" -ne 1 ] || [ "$printf_calls" -ne 1 ]; then
        cat "$WORK/rt.s"
        echo "FAIL: $opt expected one puts call and one retained printf call"
        exit 1
    fi
    if ! zcc +cpm -compiler=llvmz80 ${ZCC_CLIB:-} "$opt" -create-app \
        -o "$WORK/rt" "$DIR/runtime_printf_puts.c" >"$WORK/build.log" 2>&1; then
        cat "$WORK/build.log"
        echo "FAIL: $opt link"
        exit 1
    fi
    OUT=$("$NTVCM" "$WORK/RT.COM" 2>/dev/null | tr -d '\r')
    EXPECTED=$(printf 'direct puts\nretained printf')
    if [ "$OUT" != "$EXPECTED" ]; then
        echo "FAIL: $opt output [$OUT], expected [$EXPECTED]"
        exit 1
    fi
done
echo "PASS: llvmz80 retains printf under otherwise foldable conditions at O2/O3/Oz"
