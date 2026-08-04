#!/bin/bash
# Per-component timing for stdcbench under z88dk (Z80/CP/M).
#
# The top-level compare.sh measures the WHOLE suite.  This script isolates each
# individual sub-benchmark so you can see where a compiler's cycles actually go
# (and whether a lead/deficit is concentrated in a few components).  It uses the
# BENCH_COMPONENT mode of bench_main.c: build a program that calls ONE
# sub-benchmark exactly N times (the same rep count the real driver uses:
# c90base 8x, c90lib 40x), then:
#   * verify (+cpm, ntvcm)          -> COMPONENT OK  (correctness gate, per part)
#   * timing (+test, z88dk-ticks)   -> T-states between TIMER_START/TIMER_STOP
# A timing number is only printed when the isolated +cpm run self-checks OK.
#
# Reconciliation: the per-component cycles SUM to ~the whole-suite number from
# compare.sh (small loop/clock overhead aside).  The script prints the sum and
# the whole-suite reference so you can confirm the parts add up.
#
# Requires on PATH: zcc, z88dk-ticks; ntvcm (or NTVCM=/path); LLVMZ80EXE for the
# llvmz80 lane.  Usage:  ./component_timing.sh   (or  make components)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$HERE"
SRC="$HERE/src"; WORK="$HERE/build/components"; NTVCM="${NTVCM:-ntvcm}"
mkdir -p "$WORK"

BASE_SRCS="c90base.c c90base-data.c c90base-compression.c \
c90base-huffman-recursive.c c90base-huffman-iterative.c c90base-huffman_tree.c \
c90base-isort.c c90base-immul.c stdcbench.c portme.c bench_main.c"
LIB_SRCS="c90lib.c c90lib-lnlc.c c90lib-peep.c c90lib-peep-stm8.c c90lib-htab.c"

# component | reps | module-class(base|lib)
COMPONENTS=(
  "c90base_compression|8|base"
  "c90base_isort|8|base"
  "c90base_immul|8|base"
  "c90lib_lnlc|40|lib"
  "c90lib_peep|40|lib"
)
# lane | compiler-select flags
LANES=(
  "llvmz80|-compiler=llvmz80 -O2"
  "sdcc0|-compiler=sdcc -SO3"
  "sccz80|-compiler=sccz80 -O2"
)

ticks_between() { # $1 map  $2 bin
  local ts te
  ts=$(grep -i '^TIMER_START ' "$1" | awk '{print $3}' | sed 's,^.,,' | tr 'A-Z' 'a-z')
  te=$(grep -i '^TIMER_STOP '  "$1" | awk '{print $3}' | sed 's,^.,,' | tr 'A-Z' 'a-z')
  z88dk-ticks "$2" -start "$ts" -end "$te" -counter 49999999999 2>/dev/null | tr -d '\n'
}

build() { # $1 mode(cpm|test) $2 srcs $3 defs $4 out  -> rc; retries once (z88dk multi-file race)
  local mode="$1" srcs="$2" defs="$3" out="$4" try
  for try in 1 2; do
    rm -f "$out" "${out%.*}.map"
    ( cd "$SRC"
      if [ "$mode" = "cpm" ]; then
        eval zcc +cpm $defs $srcs -o "$out" -create-app
      else
        eval zcc +test -DBENCH_TIMER -D__Z88DK $defs $srcs -o "$out" -m
      fi ) >/dev/null 2>&1 && [ -s "$out" ] && return 0
  done
  return 1
}

# bash 3.2 (macOS) has no associative arrays -> flat results file "lane|comp|value".
RES="$WORK/results.txt"; : >"$RES"
getval() { awk -F'|' -v l="$1" -v c="$2" '$1==l&&$2==c{print $3}' "$RES"; }
for lentry in "${LANES[@]}"; do
  IFS='|' read -r lane sel <<<"$lentry"
  for centry in "${COMPONENTS[@]}"; do
    IFS='|' read -r comp reps klass <<<"$centry"
    srcs="$BASE_SRCS"; disable="-DSTDCBENCH_DISABLE_C90LIB"
    [ "$klass" = "lib" ] && { srcs="$BASE_SRCS $LIB_SRCS"; disable=""; }
    defs="$sel $disable -DBENCH_COMPONENT=$comp -DBENCH_COMPONENT_REPS=$reps"
    key="$lane/$comp"; val=""
    echo "[-] $key : verify (+cpm) ..." >&2
    com="$WORK/${lane}.${comp}.com"
    if ! build cpm "$srcs" "$defs" "$com"; then val="build-fail"
    elif ! "$NTVCM" "$com" 2>/dev/null | grep -q "COMPONENT OK"; then val="CHECK-FAIL"
    else
      echo "[-] $key : timing (+test) ..." >&2
      bin="$WORK/${lane}.${comp}.bin"; map="$WORK/${lane}.${comp}.map"
      if ! build test "$srcs" "$defs" "$bin"; then val="time-build-fail"
      else val=$(ticks_between "$map" "$bin"); fi
    fi
    echo "$lane|$comp|$val" >>"$RES"
  done
done

echo ""
echo "stdcbench per-component T-states (fixed reps: c90base 8x, c90lib 40x)"
echo "Only shown when the isolated +cpm run self-checks OK."
echo ""
printf '| %-20s | %4s |' "component" "reps"
for lentry in "${LANES[@]}"; do IFS='|' read -r lane _ <<<"$lentry"; printf ' %14s |' "$lane"; done; echo ""
printf '| %-20s | %4s |' "--------------------" "----"
for _ in "${LANES[@]}"; do printf ' %14s |' "--------------"; done; echo ""
for centry in "${COMPONENTS[@]}"; do
  IFS='|' read -r comp reps klass <<<"$centry"
  printf '| %-20s | %4s |' "$comp" "$reps"
  for lentry in "${LANES[@]}"; do IFS='|' read -r lane _ <<<"$lentry"; v=$(getval "$lane" "$comp"); printf ' %14s |' "${v:--}"; done
  echo ""
done
# per-lane sums (numeric entries only)
printf '| %-20s | %4s |' "SUM (parts)" ""
for lentry in "${LANES[@]}"; do
  IFS='|' read -r lane _ <<<"$lentry"; s=0; ok=1
  for centry in "${COMPONENTS[@]}"; do IFS='|' read -r comp _ _ <<<"$centry"
    v=$(getval "$lane" "$comp"); case "$v" in ''|*[!0-9]*) ok=0;; *) s=$((s+v));; esac; done
  [ "$ok" = 1 ] && printf ' %14s |' "$s" || printf ' %14s |' "(partial)"
done; echo ""
echo ""
echo "Whole-suite reference (compare.sh, same reps): base 414,888,705 ; base+lib 14,026,608,586 (llvmz80-O2)."
