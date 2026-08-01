/* Pure compiler-rt division test: freestanding, links directly against
 * LLVM compiler-rt's z80 divsf3.o (___divsf3), no math32, no z88dk crt0.
 * Same operands and loop count as divtest.c, for direct comparison.
 *
 * Build (needs an llvm-z80 build -- this is the one variant maintainers
 * without llvm-z80 can't rebuild themselves, hence the .bin is attached
 * pre-built to the issue):
 *   clang --target=z80 -Os -ffreestanding -nostdlib -fno-builtin \
 *       -c compilerrt_div_test.c -o compilerrt_div_test.o
 *   ld.lld -e __start -Ttext=0 compilerrt_div_test.o \
 *       <llvm-z80 build>/lib/z80/elf-runtime/builtins/divsf3.o \
 *       -o compilerrt_div_test.elf
 *   llvm-objcopy -O binary compilerrt_div_test.elf compilerrt_div_test.bin
 *
 * Measure (z88dk-ticks, raw binary, no CP/M header):
 *   llvm-objdump -t compilerrt_div_test.elf | awk '/ __start$/{print $1}'
 *   llvm-objdump -t compilerrt_div_test.elf | awk '/ _bench_halt$/{print $1}'
 *   z88dk-ticks -pc 0x<start> -end 0x<halt> compilerrt_div_test.bin
 */
static volatile float a = 3.14159f, b = 2.71828f;
volatile float rf;

__attribute__((noreturn, noinline)) void bench_halt(void) {
    for (;;) { __asm__ volatile("halt"); }
}

void _start(void) {
    __asm__ volatile("ld sp, #0xF000");
    unsigned i;
    for (i = 0; i < 2000; i++) {
        rf = a / b;
    }
    bench_halt();
}
