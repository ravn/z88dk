/* Native z88dk integer-core value oracle: separate and fused division,
 * remainder, and 16-bit multiplication at O2/O3/Oz. The harness also rejects
 * legacy compiler-rt wrapper symbols and checks native call-site coverage.
 * Multiplication wraps modulo 2^16: 1234*57 = 70338 -> 4802. */

extern int printf(const char *, ...);

/* Identical operands fuse into one core call; noinline prevents folding. */
__attribute__((noinline)) long sfuse(long a, long b, long *r) { *r = a % b; return a / b; }
__attribute__((noinline)) unsigned long ufuse(unsigned long a, unsigned long b, unsigned long *r) { *r = a % b; return a / b; }

/* Oz calls l_fast_divu_8_8x8; other levels use an inline divide loop. */
__attribute__((noinline)) unsigned char qdiv(unsigned char a, unsigned char b) { return a / b; }
__attribute__((noinline)) unsigned char qmod(unsigned char a, unsigned char b) { return a % b; }

int main(void)
{
	/* --- 16-bit + separate 32-bit: volatile blocks const-fold AND fusion --- */
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

	/* --- fused 32-bit divmod --- */
	volatile long fa = 1000000L, fb = 7L;
	volatile unsigned long ufa = 4000000000UL, ufb = 13UL;
	long sr;
	long sq = sfuse(fa, fb, &sr);
	unsigned long ur;
	unsigned long uq = ufuse(ufa, ufb, &ur);
	printf("f %ld %ld %lu %lu\n", sq, sr, uq, ur);

	/* --- 8-bit unsigned --- */
	volatile unsigned char qa = 200, qb = 7;
	printf("q %u %u\n", (unsigned)qdiv(qa, qb), (unsigned)qmod(qa, qb));
	return 0;
}
