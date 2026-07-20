#!/bin/bash
# Three-way Dhrystone 2.1 comparison harness (z88dk compiler test suite).
#
# Builds and times the same Dhrystone 2.1 sources through three lanes and
# prints a markdown table (cycles/run + DMIPS).  The three lanes isolate the
# effect of the calling convention from the effect of the compiler proper:
#
#   llvmz80/     ravn/llvm-z80 GlobalISel clang, -O2  (z80 16-bit register ABI)
#   sdcccall1/   sdcc -SO3 with --sdcccall 1          (register convention)
#   z88dk-classic/ sdcc -SO3 with --sdcccall 0        (z88dk default: stack)
#
# All three are z88dk-native builds timed with z88dk-ticks between the
# TIMER_START/TIMER_STOP labels (dhry.h -DTIMER).  Run from this directory
# with z88dk's bin on PATH and ZCCCFG set.  Paths are relative to this script.
#
# Usage:  ./compare.sh            # build + measure + print table
#         FREQ=4000000 ./compare.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

FREQ="${FREQ:-4000000}"
RUNS=20000
VAX=1757   # VAX 11/780 dhrystones/s reference for DMIPS

# lane dir | human label shown in the table
LANES=(
  "llvmz80|llvmz80 -O2 (z80 16-bit register ABI)"
  "sdcccall1|sdcc --sdcccall 1 -SO3 (register convention)"
  "z88dk-classic|sdcc --sdcccall 0 -SO3 (z88dk default, stack)"
)

# bash 3.2 (macOS) has no associative arrays; accumulate "cycles|label" rows.
ROWS=()
for entry in "${LANES[@]}"; do
    dir="${entry%%|*}"; label="${entry#*|}"
    echo "[-] Building + timing $dir ..." >&2
    ( cd "$dir" && make clean >/dev/null 2>&1 && make benchmark >/dev/null 2>&1 )
    # every lane writes its raw cycle count to dhrystone_ticks
    c="$(tr -d '\n' < "$dir/dhrystone_ticks")"
    ROWS+=("$c|$label")
done

echo ""
echo "Dhrystone 2.1 -- three-way comparison (@ $((FREQ/1000000)) MHz Z80, $RUNS runs)"
echo ""
printf '| %-52s | %-11s | %-7s |\n' "Compiler / calling convention" "cycles/run" "DMIPS"
printf '| %s | %s | %s |\n' "----------------------------------------------------" "-----------" "-------"
for row in "${ROWS[@]}"; do
    c="${row%%|*}"; label="${row#*|}"
    cpr=$(( c / RUNS ))
    dmips=$(echo "scale=4; ($RUNS.0 / ($c.0 / $FREQ)) / $VAX" | bc -l)
    printf '| %-52s | %11s | %7s |\n' "$label" "$cpr" "0$dmips"
done
