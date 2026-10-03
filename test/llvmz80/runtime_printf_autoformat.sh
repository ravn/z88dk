#!/bin/sh
set -eu

DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$DIR/test_env.sh"
ROOT=$(CDPATH= cd -- "$DIR/../.." && pwd)
WORKSPACE=$(CDPATH= cd -- "$ROOT/.." && pwd)
TMP_ROOT=${Z80_TEST_TMPDIR:-"$WORKSPACE/scratch/tmp"}
ZCC=${ZCC:-zcc}
NTVCM=${NTVCM:-ntvcm}

command -v "$ZCC" >/dev/null 2>&1 || {
    echo "SKIP: zcc not found"
    exit 0
}
mkdir -p "$TMP_ROOT"
WORK=$(mktemp -d "$TMP_ROOT/printf-autoformat.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir "$WORK/tmp"

cd "$WORK"
if ! TMPDIR="$WORK/tmp" "$ZCC" +cpm -compiler=llvmz80 --math32 -Cg-O2 \
        -create-app -o "$WORK/rt" "$DIR/runtime_printf_autoformat.c" \
        >"$WORK/build.log" 2>&1; then
    cat "$WORK/build.log"
    echo "FAIL: zcc llvmz80 printf-autoformat build failed"
    exit 1
fi

[ -f "$WORK/RT.COM" ] || {
    cat "$WORK/build.log"
    echo "FAIL: zcc did not produce RT.COM"
    exit 1
}

command -v "$NTVCM" >/dev/null 2>&1 || {
    echo "SKIP: runtime build passed; ntvcm not found (set NTVCM)"
    exit 0
}

OUT=$(TMPDIR="$WORK/tmp" "$NTVCM" "$WORK/RT.COM" 2>/dev/null | tr -d '\r')
echo "$OUT" | grep -qF "PASS autoformat" || {
    echo "FAIL: printf autoformat runtime output: [$OUT]"
    exit 1
}

echo "PASS: llvmz80 printf autoformat uses stock classic converters"
