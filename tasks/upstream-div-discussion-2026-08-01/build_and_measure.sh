#!/bin/sh
# Reproducible build + measure script for the z88dk math32-div upstream
# discussion issue. Pure z88dk toolchain only (zcc -compiler=sdcc,
# z88dk-ticks) -- no llvm-z80/clang dependency, so any z88dk maintainer can
# run this with just a z88dk checkout.
#
# Builds the SAME source (divtest.c) two ways:
#   math32_div_test  = current math32 division (m32_fsdiv, Newton-Raphson
#                       reciprocal), via `-DUSE_MATH32 -lmath32`.
#   directdiv_test   = direct restoring binary division (directdiv.h),
#                       no math32, no other float library linked.
# then times both with z88dk-ticks over the same N=2000-call loop.
#
# Usage: PATH=<z88dk>/bin:$PATH ZCCCFG=<z88dk>/lib/config ./build_and_measure.sh
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
cd "$DIR"

command -v zcc >/dev/null 2>&1 || { echo "SKIP: zcc not on PATH"; exit 0; }
command -v z88dk-ticks >/dev/null 2>&1 || { echo "SKIP: z88dk-ticks not on PATH"; exit 0; }

echo "=== building math32_div_test (math32 / Newton-Raphson reciprocal) ==="
zcc +cpm -compiler=sdcc -O2 -create-app -DUSE_MATH32 -lmath32 \
	-o math32_div_test divtest.c

echo "=== building directdiv_test (direct restoring division) ==="
zcc +cpm -compiler=sdcc -O2 -create-app \
	-o directdiv_test divtest.c

echo ""
echo "=== timing, N=2000 calls/run, z88dk-ticks ==="
m32=$(z88dk-ticks math32_div_test.com 2>/dev/null | tail -1)
direct=$(z88dk-ticks directdiv_test.com 2>/dev/null | tail -1)

echo "math32 (Newton-Raphson):   $m32 T-states total  ($(echo "$m32 / 2000" | bc -l) T-states/call)"
echo "direct (restoring div):    $direct T-states total  ($(echo "$direct / 2000" | bc -l) T-states/call)"
echo "speedup: $(echo "$m32 / $direct" | bc -l)x"

# --- Optional third build: pure compiler-rt (real Z80 asm __divsf3) -------
# Only runs if LLVM_Z80_BUILD is set to an llvm-z80 build dir. Not needed
# to reproduce the two builds above -- this one requires a full llvm-z80
# build, which is why compilerrt_div_test.bin is ALSO attached pre-built
# to the issue (see compilerrt_div_test.c for the exact build commands).
if [ -n "$LLVM_Z80_BUILD" ] && [ -x "$LLVM_Z80_BUILD/bin/clang" ]; then
	echo ""
	echo "=== building compilerrt_div_test (pure compiler-rt __divsf3, real Z80 asm) ==="
	CLANG="$LLVM_Z80_BUILD/bin/clang"
	LLD="$LLVM_Z80_BUILD/bin/ld.lld"
	OBJCOPY="$LLVM_Z80_BUILD/bin/llvm-objcopy"
	OBJDUMP="$LLVM_Z80_BUILD/bin/llvm-objdump"
	RT_LIB="$LLVM_Z80_BUILD/lib/z80/elf-runtime/builtins"
	"$CLANG" --target=z80 -Os -ffreestanding -nostdlib -fno-builtin \
		-c compilerrt_div_test.c -o compilerrt_div_test.o
	"$LLD" -e __start -Ttext=0 compilerrt_div_test.o "$RT_LIB/divsf3.o" \
		-o compilerrt_div_test.elf
	"$OBJCOPY" -O binary compilerrt_div_test.elf compilerrt_div_test.bin
	start=$("$OBJDUMP" -t compilerrt_div_test.elf | awk '/ __start$/{print $1}')
	halt=$("$OBJDUMP" -t compilerrt_div_test.elf | awk '/ _bench_halt$/{print $1}')
	rt=$(z88dk-ticks -pc "0x$start" -end "0x$halt" compilerrt_div_test.bin 2>/dev/null | tail -1)
	echo "compiler-rt (__divsf3):    $rt T-states total  ($(echo "$rt / 2000" | bc -l) T-states/call)"
	echo "speedup over math32: $(echo "$m32 / $rt" | bc -l)x"
else
	echo ""
	echo "(skipping pure compiler-rt build: set LLVM_Z80_BUILD to an llvm-z80" \
		"build dir to also reproduce that measurement -- see" \
		"compilerrt_div_test.c for manual build steps, or just run the" \
		"pre-built compilerrt_div_test.bin attached to the issue)"
fi
