#!/bin/sh
# XFAIL: ferror()/feof() return garbage under llvmz80 on classic +cpm.
#
# Oracle diff over the whole ferror/feof contract (fresh / mid-file / true EOF /
# after clearerr).  sccz80 defines the correct answer for each state; llvmz80
# must match it.  The classic oracle is
#   f_fresh=0 r_fresh=0 f_mid=0 r_mid=0 f_eof=1 r_eof=0 f_clr=1 r_clr=0
# (note f_clr=1: clearerr is a no-op macro on classic +cpm, so feof stays set).
# See xfail_ferror_feof.c for the root cause (plain int ferror/feof(FILE*) decls
# bypass the __z88dk_fastcall bridge under __STDC_ABI_ONLY, so clang tail-calls
# the stack-arg _ferror/_feof asm with the arg in a register).
#
# XFAIL = sccz80 line != llvmz80 line (the bug still holds).
# XPASS = the two lines match  -> ferror/feof fixed under llvmz80, promote to a
#         real assertion.
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
SRC="$DIR/xfail_ferror_feof.c"

command -v zcc >/dev/null 2>&1 || { echo "SKIP: zcc not on PATH"; exit 0; }
NTVCM=${NTVCM:-ntvcm}
command -v "$NTVCM" >/dev/null 2>&1 || { echo "SKIP: ntvcm not found (set NTVCM)"; exit 0; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
HEAP="-pragma-define:CLIB_MALLOC_HEAP_SIZE=4000"
NTVCM_MAXCYC=${NTVCM_MAXCYC:-10}
ntvcm_run() { "$NTVCM" -m:"$NTVCM_MAXCYC" "$@" 2>/dev/null | grep -v "^ntvcm: cycle limit"; }

run_variant() {
    label="$1"; shift
    d="$WORK/$label"; mkdir -p "$d"
    if ! zcc "$@" $HEAP -create-app -o "$d/t" "$SRC" >"$d/build.log" 2>&1; then
        case "${TEST_CLIB:-classic}" in
            newlib_*) echo "__NEWLIB_LINK_FAIL__" ;;
            *) echo "__BUILD_FAIL__" ;;
        esac
        return
    fi
    (cd "$d" && ntvcm_run t.com | tr -d '\r' | sed -n 's/^\(ff .*\)$/\1/p' | head -1)
}

V_SCC=$(run_variant scc +cpm -O2)
V_LLVM=$(run_variant llvm +cpm -compiler=llvmz80 ${ZCC_CLIB:-} -O2)

case "$V_LLVM" in
    __NEWLIB_LINK_FAIL__) echo "XFAIL: newlib CP/M FILE* not supported (ravn/z88dk#34 WONTFIX)"; exit 0 ;;
esac
[ "$V_SCC" = "__BUILD_FAIL__" ] && { echo "SKIP: sccz80 oracle build failed"; exit 0; }
[ "$V_LLVM" = "__BUILD_FAIL__" ] && { echo "FAIL: llvmz80 build failed"; exit 1; }

echo "sccz80:  ${V_SCC:-<none>}"
echo "llvmz80: ${V_LLVM:-<none>}"

# Sanity: the oracle must be all-zero on the non-EOF states (fresh/mid/clr) and
# must actually reach EOF (f_eof=1) -- otherwise the fixture didn't exercise the
# contract and any "match" would be meaningless.
case "$V_SCC" in
    "ff f_fresh=0 r_fresh=0 f_mid=0 r_mid=0 f_eof=1 r_eof=0 f_clr=1 r_clr=0") : ;;
    *) echo "FAIL: sccz80 oracle unexpected ([$V_SCC]) -- test assumption broken"; exit 1 ;;
esac

if [ "$V_LLVM" = "$V_SCC" ]; then
    echo "XPASS: ferror/feof now match sccz80 under llvmz80 -- bug fixed, promote to a real test"
    exit 0
fi

echo "XFAIL: ferror/feof diverge under llvmz80 (llvm=[$V_LLVM] vs oracle=[$V_SCC])"
exit 0
