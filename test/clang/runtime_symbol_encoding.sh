#!/bin/sh
# LLVM-Z80 only: dotted static names must not alias ordinary C globals.
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/test_env.sh"
command -v zcc >/dev/null 2>&1 || { echo "SKIP: zcc not on PATH"; exit 0; }
NTVCM=${NTVCM:-ntvcm}
command -v "$NTVCM" >/dev/null 2>&1 || { echo "SKIP: ntvcm not found"; exit 0; }
mkdir -p "$DIR/../../../scratch/tmp"
WORK=$(mktemp -d "$DIR/../../../scratch/tmp/symbol-encoding.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

for opt in -O2 -O3 --opt-code-size; do
    if ! zcc +cpm -compiler=llvmz80 ${ZCC_CLIB:-} "$opt" -create-app \
        -o "$WORK/rt" "$DIR/runtime_symbol_encoding.c" >"$WORK/build.log" 2>&1; then
        cat "$WORK/build.log"
        echo "FAIL: $opt symbol encoding link"
        exit 1
    fi
    OUT=$("$NTVCM" "$WORK/RT.COM" 2>/dev/null | tr -d '\r')
    if [ "$OUT" != "PASS" ]; then
        echo "FAIL: $opt output [$OUT], expected [PASS]"
        exit 1
    fi
done
echo "PASS: llvmz80 static symbol encoding at O2/O3/Oz"
