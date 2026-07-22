#!/bin/sh
# Build test for the stdio FILE* layer: see runtime_file.c.
#
# BUILD-ONLY: the FILE* round-trip is exercised for real under MAME with a disk
# image (the FILE* layer is 16/16 MAME-verified); ntvcm does not persist CP/M
# files, so here we only assert the layer LINKS.  A heap is required for the
# FILE* buffers.
#
# GREEN (classic): links -> the FILE* layer is present.
# NEWLIB: fails to link (undefined asm_target_open_p1/p2); skip-listed in
#         run_all.sh.  When that gap closes the build succeeds and this PASSes.
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
SRC="$DIR/runtime_file.c"

command -v zcc >/dev/null 2>&1 || { echo "SKIP: zcc not on PATH"; exit 0; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $1"; exit 1; }

if ! zcc +cpm -compiler=llvmz80 ${ZCC_CLIB:-} -O2 \
        -pragma-define:CLIB_MALLOC_HEAP_SIZE=4000 \
        -create-app -o "$WORK/rt" "$SRC" >"$WORK/build.log" 2>&1; then
    echo "--- build log ---"; cat "$WORK/build.log"
    fail "FILE* layer did not link"
fi
[ -f "$WORK/rt.com" ] || fail "no .com produced"
echo "PASS: FILE* layer links (fopen/fputs/fgets/fclose)"
