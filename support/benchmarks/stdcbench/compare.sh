#!/bin/bash
# stdcbench cross-compiler sweep harness for z88dk +cpm/+test (Z80/CP/M).
#
# Builds the vendored stdcbench (support/benchmarks/stdcbench/src) through every
# Z80 C compiler z88dk can drive and prints a markdown table with, per lane:
#   * .COM size (bytes)  -- code-density axis
#   * T-states (cycles)  -- speed axis, measured by z88dk-ticks over a FIXED,
#                           deterministic workload (see src/portme.c: the
#                           stdcbench clock is a pure call-counter, so every
#                           compiler runs exactly the same number of iterations)
#   * self-check verdict -- stdcbench's own per-module result validation, run
#                           under an emulator; a timing number is only trusted
#                           when this is OK.
#
# Two builds per lane:
#   verify    (+cpm -create-app, run under ntvcm)  -> correctness gate + .COM size
#   benchmark (+test -DBENCH_TIMER, z88dk-ticks)   -> cycles between TIMER labels
#
# HEADLINE (comparable) module set = c90base only.  The llvmz80 lanes ALSO run
# c90lib (standard-library module) always: both former llvmz80 toolchain
# blockers are fixed (the z80asm .asciz split in splitascii.pl and the -O2
# TruncInstCombine cyclic crash) and the heap is set up in portme.h, so
# malloc/calloc/realloc/free all work.  Per stdcbench RULES a module dropped for
# a lane is dropped for all HEADLINE comparisons; the c90base scores stay
# strictly comparable across lanes, while c90lib is reported for whichever lanes
# build it.  MODULES=all additionally enables c90lib on the sdcc/sccz80 lanes.
#
# Usage:  ./compare.sh                 # c90base (all lanes) + c90lib (llvmz80)
#         MODULES=all ./compare.sh     # additionally c90lib on sdcc/sccz80
#         FREQ=4000000 ./compare.sh
#
# Requires on PATH: zcc, z88dk-ticks (z88dk/bin), and ntvcm (or NTVCM=/path).
# Env: LLVMZ80EXE must point at the ravn/llvm-z80 clang for the llvmz80 lanes.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

SRC="$HERE/src"
WORK="$HERE/build"
NTVCM="${NTVCM:-ntvcm}"
FREQ="${FREQ:-4000000}"
MODULES="${MODULES:-base}"      # base | all
mkdir -p "$WORK"

# --- source file sets -------------------------------------------------------
BASE_SRCS="c90base.c c90base-data.c c90base-compression.c \
c90base-huffman-recursive.c c90base-huffman-iterative.c c90base-huffman_tree.c \
c90base-isort.c c90base-immul.c stdcbench.c portme.c bench_main.c"
LIB_SRCS="c90lib.c c90lib-lnlc.c c90lib-peep.c c90lib-peep-stm8.c c90lib-htab.c"

if [ "$MODULES" = "all" ]; then
    SRCS="$BASE_SRCS $LIB_SRCS"; MODFLAG=""
else
    SRCS="$BASE_SRCS"; MODFLAG="-DSTDCBENCH_DISABLE_C90LIB"
fi

# --- lane table: name | opt-label | compiler-select flags | shim(0/1) --------
# shim=1 injects '--sdcccall 1' via a PATH shim on z88dk-zsdcc (zcc filters it).
LANES=(
  # -Os and -O2 are byte- and cycle-identical on this load, so only -O2 is run
  # (re-add an "llvmz80-Os|-Os|...-Os|0" entry if that ever stops holding).
  "llvmz80-O2|-O2 |+X -compiler=llvmz80 -O2|0"
  "sdcc0     |-SO3|+X -compiler=sdcc -SO3|0"
  # sdcc1 (--sdcccall 1) dropped: always CHECK-FAIL against z88dk's sdcccall(0)
  # precompiled clib (c90base_immul/isort miscompile) -- not a trustworthy lane.
  "sccz80    |-O2 |+X -compiler=sccz80 -O2|0"
)

# --- sdcccall-1 PATH shim ---------------------------------------------------
SHIMDIR="$WORK/.shim"
make_shim() {
    mkdir -p "$SHIMDIR"
    printf '#!/bin/bash\nexec "%s" --sdcccall 1 "$@"\n' "$(command -v z88dk-zsdcc)" > "$SHIMDIR/z88dk-zsdcc"
    chmod +x "$SHIMDIR/z88dk-zsdcc"
}

build_one() {
    # $1 name  $2 select-flags  $3 shim  $4 mode(cpm|test)  $5 out  -> echoes ok/fail
    local name="$1" sel="$2" shim="$3" mode="$4" out="$5"
    local pfx run=""
    [ "$shim" = "1" ] && { make_shim; run="PATH=$SHIMDIR:$PATH"; }
    # Per-lane module set.  The llvmz80 lanes fully support c90lib now (heap set
    # up in portme.h + both former toolchain blockers fixed: the z80asm .asciz
    # split and the -O2 TruncInstCombine crash), so they always build the full
    # module set regardless of $MODULES.  Other lanes follow the global $MODULES.
    local lmod="$MODFLAG" lsrcs="$SRCS"
    case "$name" in
        llvmz80*) lmod=""; lsrcs="$BASE_SRCS $LIB_SRCS" ;;
    esac
    ( cd "$SRC"
      if [ "$mode" = "cpm" ]; then
          eval $run zcc "${sel/+X/+cpm}" $lmod $lsrcs -o "$out" -create-app
      else
          eval $run zcc "${sel/+X/+test}" -DBENCH_TIMER $lmod -D__Z88DK $lsrcs -o "$out" -m
      fi ) >/dev/null 2>&1
}

ticks_between() {
    # $1 = .map  $2 = .bin
    local ts te
    ts=$(grep -i '^TIMER_START ' "$1" | awk '{print $3}' | sed 's,^.,,' | tr 'A-Z' 'a-z')
    te=$(grep -i '^TIMER_STOP '  "$1" | awk '{print $3}' | sed 's,^.,,' | tr 'A-Z' 'a-z')
    z88dk-ticks "$2" -start "$ts" -end "$te" -counter 49999999999 2>/dev/null | tr -d '\n'
}

ROWS=()
for entry in "${LANES[@]}"; do
    IFS='|' read -r name opt sel shim <<<"$entry"
    name="$(echo "$name" | xargs)"; opt="$(echo "$opt" | xargs)"
    echo "[-] $name : building verify (+cpm) ..." >&2
    com="$WORK/${name}.com"; bin="$WORK/${name}.bin"; map="$WORK/${name}.map"
    rm -f "$com" "$bin" "$map"
    status="build-fail"; size="-"; cyc="-"
    if build_one "$name" "$sel" "$shim" cpm "$com" && [ -s "$com" ]; then
        size=$(stat -f%z "$com" 2>/dev/null || stat -c%s "$com")
        out="$("$NTVCM" "$com" 2>/dev/null || true)"
        if echo "$out" | grep -q "STDCBENCH OK"; then status="OK"; else status="CHECK-FAIL"; fi
    fi
    echo "[-] $name : building benchmark (+test) ..." >&2
    if [ "$status" = "OK" ] && build_one "$name" "$sel" "$shim" test "$bin" && [ -s "$bin" ]; then
        cyc=$(ticks_between "$map" "$bin")
    fi
    ROWS+=("$name|$opt|$size|$cyc|$status")
done

echo ""
echo "stdcbench $(grep -o 'stdcbench [0-9.]*' "$SRC/stdcbench.c" | head -1 | awk '{print $2}') -- cross-compiler sweep (module set: $MODULES)"
echo "Fixed deterministic workload; cycles = T-states via z88dk-ticks; size = CP/M .COM bytes."
echo "Note: llvmz80 lanes always include c90lib (full module set); other lanes follow module set above."
echo ""
printf '| %-12s | %-4s | %-10s | %-14s | %-10s |\n' "Compiler" "opt" ".COM bytes" "cycles" "self-check"
printf '| %s | %s | %s | %s | %s |\n' "------------" "----" "----------" "--------------" "----------"
for row in "${ROWS[@]}"; do
    IFS='|' read -r name opt size cyc status <<<"$row"
    printf '| %-12s | %-4s | %10s | %14s | %-10s |\n' "$name" "$opt" "$size" "$cyc" "$status"
done
