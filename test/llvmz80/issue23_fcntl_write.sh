#!/bin/sh
set -eu
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$DIR/test_env.sh"
command -v "$ZCC" >/dev/null 2>&1 || { echo "SKIP: zcc not found"; exit 0; }
command -v "$NTVCM" >/dev/null 2>&1 || { echo "SKIP: ntvcm not found"; exit 0; }

WORK=$(mktemp -d "$Z80_TEST_TMPDIR/fcntl-write.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir "$WORK/tmp"
cd "$WORK"
if ! TMPDIR="$WORK/tmp" "$ZCC" +cpm -compiler=llvmz80 -Cg-O2 \
    -create-app -o "$WORK/rt" "$DIR/issue23_fcntl_write.c" >build.log 2>&1; then
    cat build.log
    echo "FAIL: fcntl write build"
    exit 1
fi
if ! OUT=$(perl -e 'alarm shift; exec @ARGV' 10 "$NTVCM" "$WORK/RT.COM" 2>run.log); then
    cat run.log
    echo "FAIL: fcntl write emulator run"
    exit 1
fi
OUT=$(printf '%s\n' "$OUT" | tr -d '\r')
printf '%s\n' "$OUT" | grep -qx 'write=3' || { echo "FAIL: write count: [$OUT]"; exit 1; }
[ -f WP.DAT ] || { echo "FAIL: write did not create WP.DAT"; exit 1; }
printf XYZ >expected
dd if=WP.DAT of=actual bs=1 count=3 2>/dev/null
cmp -s expected actual || { echo "FAIL: WP.DAT does not contain XYZ"; exit 1; }
echo "PASS: classic fcntl write creates XYZ in an isolated working directory"
