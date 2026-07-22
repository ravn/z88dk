#!/bin/sh
# XFAIL: standard 5-arg bsearch is a deliberate CLASSIC-DESIGN gap on +cpm.
#
# Expected: the program FAILS TO BUILD (bsearch undeclared in classic stdio.h,
# because the classic clib only ships the non-standard 4-arg l_bsearch — see
# xfail_bsearch.c for the full 2005 "avoid the 16-bit multiply" rationale).
#
# XFAIL  = build failed as expected (the documented gap holds).
# XPASS  = it built (the gap closed upstream) -> retire this xfail.
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
SRC="$DIR/xfail_bsearch.c"

command -v zcc >/dev/null 2>&1 || { echo "SKIP: zcc not on PATH"; exit 0; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if zcc +cpm -compiler=llvmz80 ${ZCC_CLIB:-} -O2 -create-app -o "$WORK/rt" "$SRC" >"$WORK/build.log" 2>&1; then
    echo "XPASS: standard bsearch now builds on +cpm -- gap closed, retire xfail_bsearch"
else
    reason=$(grep -iE "undeclared|undefined|bsearch" "$WORK/build.log" | head -1 | sed 's/^[[:space:]]*//')
    echo "XFAIL: standard 5-arg bsearch absent on classic +cpm (classic-design gap) -- $reason"
fi
