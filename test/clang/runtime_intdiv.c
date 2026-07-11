/* Runtime regression test: the ravn/llvm-z80 backend emits compiler-rt runtime
 * helper names (__mulhi3/__divhi3/__modhi3 and their unsigned + 32-bit __*si3
 * siblings) for non-trivial integer multiply/divide/modulo.  z88dk's ez80clang
 * runtime (l/clang) does NOT export those names -- it was written for a
 * different compiler -- so before libsrc/l/llvmz80/ was added, any program with
 * a non-constant 16- or 32-bit divide failed to link with
 * "undefined symbol: ___mulhi3".
 *
 * This exercises all six 16-bit helpers and the four 32-bit helpers with
 * VOLATILE operands (so the compiler cannot constant-fold them and must emit
 * the runtime calls).  It links against z80_crt0.lib and prints the results;
 * the harness (runtime_intdiv.sh) compares them against the host-computed
 * expected values.
 *
 * Values are chosen so the 16-bit multiply wraps mod 2^16 (1234*57 = 70338 ->
 * 4802), exercising the low-16 __mulhi3 == __umulhi3 aliasing.
 */

extern int printf(const char *, ...);

int main(void)
{
	volatile int a = 1234, b = 57;
	volatile unsigned ua = 50000u, ub = 7u;
	volatile long la = 1000000L, lb = 7L;
	volatile unsigned long lua = 4000000000UL, lub = 13UL;

	printf("h %d %d %d %u %u %u\n",
	       (int)(a * b), (int)(a / b), (int)(a % b),
	       (unsigned)(ua * ub), (unsigned)(ua / ub), (unsigned)(ua % ub));
	printf("l %ld %ld %lu %lu\n",
	       (long)(la / lb), (long)(la % lb),
	       (unsigned long)(lua / lub), (unsigned long)(lua % lub));
	return 0;
}
