#!/bin/sh
# Reproducible benchmark: math32 vs compiler-rt, all f32 libcalls, incl. the
# -ffast-math compare variant. ravn/llvm-z80#277.
#
# Measures the current native math32 path against standalone compiler-rt.
# Timings include loop/caller overhead; they are not isolated core timings.
#
# Method for each op:
#   math32 side:      the REAL production pipeline, `zcc +cpm
#                      -compiler=llvmz80 -lmath32`, N=2000 loop, ticks_cpm.py
#                      on the .com. zcc selects
#                      --target=z80-unknown-none-z88dk, which lowers float
#                      libcalls to the existing cm32_sdcc_* runtime entries.
#   compiler-rt side: a standalone freestanding binary (no CP/M CRT): plain
#                      portable C compiled `--target=z80 -Os` (optionally
#                      -ffast-math) with no z88dk target, so clang emits the
#                      DEFAULT-ABI libcall; linked directly against the
#                      prebuilt compiler-rt .o for that op; N=2000 loop.
#                      z88dk-ticks stops at the explicit _bench_halt address.
#                      Letting clang itself lower the libcall (rather than
#                      hand-rolling the register shuffle) is deliberate: it
#                      is what a real freestanding compiler-rt caller does,
#                      and avoids any hand-written-asm ABI mismatch bugs.
#
# All operand values match the historical baseline (design doc Sec 9/9b):
# 3.14159f / 2.71828f for the two-float ops, 12345.678f for f2i, 12345 for
# i2f.
#
# Usage: PATH=<z88dk>/bin:$PATH ZCCCFG=<z88dk>/lib/config \
#        LLVMZ80EXE=<llvm-z80 build>/bin/clang \
#        LLVM_Z80_BUILD=<llvm-z80 build dir> ./bench_math32_vs_compilerrt.sh
set -e
export LC_NUMERIC=C LC_ALL=C
DIR=$(cd "$(dirname "$0")" && pwd)
WORKSPACE_ROOT=$(cd "$DIR/../../.." && pwd)

fail() { echo "ERROR: $*" >&2; exit 1; }

. "$DIR/test_env.sh"
MATH32_DIR="$DIR/../../libsrc"
TICKS_CPM="$WORKSPACE_ROOT/scratch/dcc-clang-bench/ticks_cpm.py"

command -v zcc >/dev/null 2>&1 || fail "zcc not found on PATH"
command -v z88dk-ticks >/dev/null 2>&1 || fail "z88dk-ticks not found on PATH"
command -v python3 >/dev/null 2>&1 || fail "python3 not found on PATH"
[ -x "$LLVMZ80EXE" ] || fail "missing llvm-z80 clang: $LLVMZ80EXE"
[ -f "$TICKS_CPM" ] || fail "missing CP/M ticks harness: $TICKS_CPM"
CLANG="$LLVMZ80EXE"
LLD="$LLVM_Z80_BUILD/bin/ld.lld"
OBJCOPY="$LLVM_Z80_BUILD/bin/llvm-objcopy"
OBJDUMP="$LLVM_Z80_BUILD/bin/llvm-objdump"
RT_LIB="$LLVM_Z80_BUILD/lib/z80/elf-runtime/builtins"
RT_TICKS_LIMIT=50000000
for f in "$CLANG" "$LLD" "$OBJCOPY" "$OBJDUMP"; do
	[ -x "$f" ] || fail "missing required tool: $f"
done
for f in addsf3.o mulsf3.o divsf3.o cmpsf2.o fixsfsi.o floatsisf.o; do
	[ -s "$RT_LIB/$f" ] || fail "missing compiler-rt runtime object: $RT_LIB/$f"
done

WORK=$(mktemp -d "$WORKSPACE_ROOT/scratch/tmp/benchkeep.XXXXXX") \
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

# --- math32 side: real zcc pipeline, N=2000 loop -----------------------------
# $1 = op label, $2 = C loop body, $3 = extra zcc flags (e.g. -ffast-math).
# The Z88DK triple calls existing math32 entries, including the conversion
# needed by the shared template's `(int)rf` return.
bench_math32() {
	label=$1; body=$2; extra=$3
	src="$WORK/m32_$label.c"
	cat >"$src" <<-EOF
	static volatile float a = 3.14159f, b = 2.71828f;
	static volatile float fa = 12345.678f;
	static volatile int ia = 12345;
	int main(void) {
	    unsigned i;
	    volatile int r = 0;
	    volatile float rf = 0;
	    for (i = 0; i < 2000; i++) { $body }
	    return r + (int)rf;
	}
	EOF
	if ! zcc +cpm -compiler=llvmz80 -O2 $extra -create-app \
		-L"$MATH32_DIR" -lmath32 \
		-o "$WORK/m32_$label" "$src" >"$WORK/m32_$label.log" 2>&1; then
		echo "BUILD FAILED ($label, math32):"; cat "$WORK/m32_$label.log"; exit 1
	fi
	com="$WORK/m32_$label.com"
	[ -s "$com" ] || { echo "BUILD FAILED ($label, math32): missing $com"; exit 1; }
	if ! TMPDIR="$WORK" Z88DK_TICKS="$(command -v z88dk-ticks)" \
		python3 "$TICKS_CPM" "$com" \
		>"$WORK/m32_$label.stdout" 2>"$WORK/m32_$label.ticks"; then
		echo "TICKS FAILED ($label, math32):"; cat "$WORK/m32_$label.stdout" "$WORK/m32_$label.ticks"; exit 1
	fi
	total=$(awk '$1 == "[ticks]" && $3 == "cycles" && $2 ~ /^[0-9]+$/ { n++; value=$2 }
		END { if (n != 1) exit 1; print value }' "$WORK/m32_$label.ticks") \
		|| { echo "INVALID TICKS ($label, math32):"; cat "$WORK/m32_$label.ticks"; exit 1; }
	[ "$total" -gt 0 ] || { echo "INVALID TICKS ($label, math32): $total"; exit 1; }
	printf '%s\n' "$total"
}

# --- compiler-rt side: standalone freestanding binary, N=2000 loop ----------
# $1 = op label, $2 = C loop body, $3 = extra clang flags, $4 = obj files
bench_compilerrt() {
	label=$1; body=$2; extra=$3; objs=$4
	src="$WORK/rt_$label.c"
	cat >"$src" <<-EOF
	static volatile float a = 3.14159f, b = 2.71828f;
	static volatile float fa = 12345.678f;
	static volatile int ia = 12345;
	volatile int r;
	volatile float rf;
	__attribute__((noreturn, noinline)) void bench_halt(void) {
	    for (;;) { __asm__ volatile("halt"); }
	}
	void _start(void) {
	    __asm__ volatile("ld sp, #0xF000");
	    for (unsigned i = 0; i < 2000; i++) { $body }
	    bench_halt();
	}
	EOF
	obj="$WORK/rt_$label.o"
	elf="$WORK/rt_$label.elf"
	bin="$WORK/rt_$label.bin"
	"$CLANG" --target=z80 -Os $extra -ffreestanding -nostdlib -fno-builtin \
		-c "$src" -o "$obj" 2>"$WORK/rt_$label.log" \
		|| { echo "COMPILE FAILED ($label, compiler-rt):"; cat "$WORK/rt_$label.log"; exit 1; }
	# shellcheck disable=SC2086
	"$LLD" -e __start -Ttext=0 "$obj" $objs -o "$elf" 2>"$WORK/rt_$label.link.log" \
		|| { echo "LINK FAILED ($label, compiler-rt):"; cat "$WORK/rt_$label.link.log"; exit 1; }
	[ -s "$elf" ] || { echo "LINK FAILED ($label, compiler-rt): missing $elf"; exit 1; }
	"$OBJCOPY" -O binary "$elf" "$bin"
	[ -s "$bin" ] || { echo "LINK FAILED ($label, compiler-rt): missing or empty $bin"; exit 1; }
	start=$("$OBJDUMP" -t "$elf" | awk '$NF == "__start" { n++; value=$1 }
		END { if (n != 1) exit 1; print value }') \
		|| { echo "LINK FAILED ($label, compiler-rt): missing unique __start symbol"; exit 1; }
	halt=$("$OBJDUMP" -t "$elf" | awk '$NF == "_bench_halt" { n++; value=$1 }
		END { if (n != 1) exit 1; print value }') \
		|| { echo "LINK FAILED ($label, compiler-rt): missing unique _bench_halt symbol"; exit 1; }
	if ! z88dk-ticks -pc "0x$start" -end "0x$halt" \
		-counter "$RT_TICKS_LIMIT" "$bin" \
		>"$WORK/rt_$label.ticks" 2>"$WORK/rt_$label.ticks.err"; then
		echo "TICKS FAILED ($label, compiler-rt):"; cat "$WORK/rt_$label.ticks" "$WORK/rt_$label.ticks.err"; exit 1
	fi
	total=$(awk 'NF == 0 { next }
		$0 ~ /^[0-9]+$/ { n++; value=$0; next }
		$0 ~ /^Ticks: [0-9]+$/ { n++; value=$2; next }
		{ bad=1 }
		END { if (n != 1 || bad) exit 1; print value }' "$WORK/rt_$label.ticks") \
		|| { echo "INVALID TICKS ($label, compiler-rt):"; cat "$WORK/rt_$label.ticks" "$WORK/rt_$label.ticks.err"; exit 1; }
	[ "$total" -gt 0 ] || { echo "INVALID TICKS ($label, compiler-rt): $total"; exit 1; }
	[ "$total" -lt "$RT_TICKS_LIMIT" ] \
		|| { echo "INCOMPLETE TICKS ($label, compiler-rt): hit $RT_TICKS_LIMIT-cycle watchdog"; exit 1; }
	printf '%s\n' "$total"
}

# op, math32 body, compiler-rt body, compiler-rt objs (space-separated),
# extra math32 flags, extra compiler-rt flags
run_op() {
	label=$1; m32body=$2; rtbody=$3; rtobjs=$4; extra_m32=$5; extra_rt=$6
	t_m32=$(bench_math32 "$label" "$m32body" "$extra_m32")
	t_rt=$(bench_compilerrt "$label" "$rtbody" "$extra_rt" "$rtobjs")
	printf "%-16s math32=%-10s (%.1f T/call)  compiler-rt=%-10s (%.1f T/call)\n" \
		"$label" "$t_m32" "$(echo "$t_m32 / 2000" | bc -l)" \
		"$t_rt" "$(echo "$t_rt / 2000" | bc -l)"
}

echo "=== math32 vs compiler-rt, N=2000 loop, z88dk-ticks ==="
# Fixed operands every iteration (assignment, not +=) -- accumulating the
# result would feed a different (drifting) operand into the op each pass,
# confounding the timing with math32's shift-count-depends-on-magnitude
# behaviour. Matches the original 1-instruction-body methodology (design
# doc Sec 9/9b): same op, same inputs, every call.
run_op add     'rf = a + b;'   'rf = a + b;'   "$RT_LIB/addsf3.o"
run_op sub     'rf = a - b;'   'rf = a - b;'   "$RT_LIB/addsf3.o"
run_op mul     'rf = a * b;'   'rf = a * b;'   "$RT_LIB/mulsf3.o"
run_op div     'rf = a / b;'   'rf = a / b;'   "$RT_LIB/divsf3.o"
run_op compare 'r = (a < b);'  'r = (a < b);'  "$RT_LIB/cmpsf2.o"
run_op f2i     'r = (int)fa;'  'r = (int)fa;'  "$RT_LIB/fixsfsi.o"
run_op i2f     'rf = (float)ia;' 'rf = (float)ia;' "$RT_LIB/floatsisf.o"
echo ""
echo "=== -ffast-math compare ==="
run_op compare_fast 'r = (a < b);' 'r = (a < b);' "$RT_LIB/cmpsf2.o" "-ffast-math" "-ffast-math"
echo "PASS: bench_math32_vs_compilerrt"
