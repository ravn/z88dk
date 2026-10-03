#!/bin/sh
set -eu
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$DIR/test_env.sh"
command -v "$ZCC" >/dev/null 2>&1 || { echo "SKIP: zcc not found"; exit 0; }
command -v "$NTVCM" >/dev/null 2>&1 || { echo "SKIP: ntvcm not found"; exit 0; }

WORK=$(mktemp -d "$Z80_TEST_TMPDIR/stdio-abi.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir "$WORK/tmp"
cd "$WORK"
if ! TMPDIR="$WORK/tmp" "$ZCC" +cpm -compiler=llvmz80 -Cg-O2 \
    -create-app -o "$WORK/rt" "$DIR/issue22_stdio_abi.c" >build.log 2>&1; then
    cat build.log
    echo "FAIL: stdio ABI build"
    exit 1
fi
if ! OUT=$(perl -e 'alarm shift; exec @ARGV' 10 "$NTVCM" "$WORK/RT.COM" 2>run.log); then
    cat run.log
    echo "FAIL: stdio ABI emulator run"
    exit 1
fi
OUT=$(printf '%s\n' "$OUT" | tr -d '\r')
printf '%s\n' "$OUT" | grep -qx DONE || { echo "FAIL: missing DONE: [$OUT]"; exit 1; }
for fn in fputs fgets ungetc fgetpos; do
    printf '%s\n' "$OUT" | grep -q "^$fn=.* OK$" || {
        echo "FAIL: $fn: [$OUT]"
        exit 1
    }
done
[ -f A.DAT ] || { echo "FAIL: stdio did not create A.DAT"; exit 1; }
printf 'hello\n' >expected
dd if=A.DAT of=actual bs=1 count=6 2>/dev/null
cmp -s expected actual || { echo "FAIL: A.DAT does not contain hello"; exit 1; }
echo "PASS: classic fputs/fgets/ungetc/fgetpos in an isolated working directory"
