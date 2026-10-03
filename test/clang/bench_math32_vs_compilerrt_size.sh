#!/bin/sh
# Reproducible benchmark: code SIZE of math32 vs compiler-rt division.
# ravn/llvm-z80 #277. Companion to bench_math32_vs_compilerrt.sh (which
# measures T-states/call, not bytes).
#
# Which division closure is smaller? On a byte-constrained target (e.g. an
# RC700 2 KB PROM) that can matter as much as speed.
#
# Method: build a "baseline" program (same crt0/config, but NO float op) and
# a "div" program (one `float` division, nothing else) through each
# pipeline, then diff the linked artifact sizes. The delta isolates the
# division closure itself from fixed crt0/startup/config overhead that both
# programs pay equally.
#   math32 side:      real zcc pipeline (`+cpm -compiler=llvmz80
#                      -L<libsrc> -lmath32`); its
#                      --target=z80-unknown-none-z88dk lowering calls the
#                      existing cm32_sdcc_fsdiv runtime entry; .com size.
#   compiler-rt side:  standalone freestanding binary (no z88dk crt0),
#                      linked against the prebuilt divsf3.o; .bin file size.
# Both sides deliberately avoid any other float/int op (no (int) cast, no
# second op) so nothing but the division itself differs between baseline
# and div builds.
#
# Usage: PATH=<z88dk>/bin:$PATH ZCCCFG=<z88dk>/lib/config \
#        LLVMZ80EXE=<llvm-z80 build>/bin/clang \
#        LLVM_Z80_BUILD=<llvm-z80 build dir> \
#        ./bench_math32_vs_compilerrt_size.sh
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
WORKSPACE_ROOT=$(cd "$DIR/../../.." && pwd)

fail() { echo "ERROR: $*" >&2; exit 1; }

. "$DIR/test_env.sh"
MATH32_DIR="$DIR/../../libsrc"

command -v zcc >/dev/null 2>&1 || fail "zcc not found on PATH"
[ -x "$LLVMZ80EXE" ] || fail "missing llvm-z80 clang: $LLVMZ80EXE"
CLANG="$LLVMZ80EXE"
LLD="$LLVM_Z80_BUILD/bin/ld.lld"
OBJCOPY="$LLVM_Z80_BUILD/bin/llvm-objcopy"
RT_LIB="$LLVM_Z80_BUILD/lib/z80/elf-runtime/builtins"
for f in "$CLANG" "$LLD" "$OBJCOPY"; do
	[ -x "$f" ] || fail "missing required tool: $f"
done
for f in divsf3.o; do
	[ -s "$RT_LIB/$f" ] || fail "missing compiler-rt runtime object: $RT_LIB/$f"
done

WORK=$(mktemp -d "$WORKSPACE_ROOT/scratch/tmp/benchsize.XXXXXX") \
	|| fail "could not create benchmark work directory under scratch/tmp"
cleanup() {
	status=$?
	if [ -n "${WORK:-}" ] && [ -d "$WORK" ]; then
		if [ "$status" -eq 0 ]; then
			rm -rf "$WORK"
		else
			echo "Benchmark artifacts retained at $WORK" >&2
		fi
	fi
}
trap cleanup EXIT

# --- math32 side --------------------------------------------------------
# $1 = label, $2 = extra body (empty for baseline, one division for div).
build_math32() {
	label=$1; body=$2
	src="$WORK/m32_$label.c"
	cat >"$src" <<-EOF
	static volatile float a = 3.14159f, b = 2.71828f;
	int main(void) {
	    $body
	    return 0;
	}
	EOF
	if ! zcc +cpm -compiler=llvmz80 -O2 -create-app \
		-L"$MATH32_DIR" -lmath32 \
		-o "$WORK/m32_$label" "$src" >"$WORK/m32_$label.log" 2>&1; then
		echo "BUILD FAILED (m32 $label):"; cat "$WORK/m32_$label.log"; exit 1
	fi
	[ -s "$WORK/m32_$label.com" ] || { echo "BUILD FAILED (m32 $label): missing or empty .com"; exit 1; }
	wc -c <"$WORK/m32_$label.com" | tr -d ' '
}

# --- compiler-rt side ----------------------------------------------------
# $1 = label, $2 = extra body, $3 = extra obj files to link.
build_compilerrt() {
	label=$1; body=$2; objs=$3
	src="$WORK/rt_$label.c"
	cat >"$src" <<-EOF
	static volatile float a = 3.14159f, b = 2.71828f;
	volatile float rf;
	__attribute__((noreturn, noinline)) void bench_halt(void) {
	    for (;;) { __asm__ volatile("halt"); }
	}
	void _start(void) {
	    __asm__ volatile("ld sp, #0xF000");
	    $body
	    bench_halt();
	}
	EOF
	obj="$WORK/rt_$label.o"
	elf="$WORK/rt_$label.elf"
	bin="$WORK/rt_$label.bin"
	"$CLANG" --target=z80 -Os -ffreestanding -nostdlib -fno-builtin \
		-c "$src" -o "$obj" 2>"$WORK/rt_$label.log" \
		|| { echo "COMPILE FAILED (rt $label):"; cat "$WORK/rt_$label.log"; exit 1; }
	# shellcheck disable=SC2086
	"$LLD" -e __start -Ttext=0 "$obj" $objs -o "$elf" 2>"$WORK/rt_$label.link.log" \
		|| { echo "LINK FAILED (rt $label):"; cat "$WORK/rt_$label.link.log"; exit 1; }
	[ -s "$elf" ] || { echo "LINK FAILED (rt $label): missing or empty $elf"; exit 1; }
	"$OBJCOPY" -O binary "$elf" "$bin"
	[ -s "$bin" ] || { echo "LINK FAILED (rt $label): missing or empty $bin"; exit 1; }
	wc -c <"$bin" | tr -d ' '
}

echo "=== code size: math32 vs compiler-rt division, delta vs no-op baseline ==="

m32_base=$(build_math32 base "")
m32_div=$(build_math32 div  "volatile float rf = a / b;")
rt_base=$(build_compilerrt base "" "")
rt_div=$(build_compilerrt div "rf = a / b;" "$RT_LIB/divsf3.o")

m32_delta=$((m32_div - m32_base))
rt_delta=$((rt_div - rt_base))

printf "math32:      baseline=%s  +div=%s  delta=%s bytes\n" "$m32_base" "$m32_div" "$m32_delta"
printf "compiler-rt: baseline=%s  +div=%s  delta=%s bytes\n" "$rt_base" "$rt_div" "$rt_delta"

if [ "$m32_delta" -lt "$rt_delta" ]; then
	echo "winner: math32 (smaller by $((rt_delta - m32_delta)) bytes)"
elif [ "$rt_delta" -lt "$m32_delta" ]; then
	echo "winner: compiler-rt (smaller by $((m32_delta - rt_delta)) bytes)"
else
	echo "tie"
fi

echo "PASS: bench_math32_vs_compilerrt_size (m32_delta=$m32_delta, rt_delta=$rt_delta)"
