/* Volatile stack locals and stack-passed output pointers must survive
 * integer cores, including the fast cores that clobber IX. */
#include <stdio.h>

__attribute__((noinline))
long divide(long a, long b, long *remainder, unsigned *checksum) {
    volatile unsigned local[3] = {19, 23, 29};
    long q = a / b;
    *remainder = a % b;
    *checksum = local[0] + local[1] + local[2];
    return q;
}

__attribute__((noinline))
unsigned long multiply(unsigned long a, unsigned long b) {
    volatile unsigned local[3] = {19, 23, 29};
    unsigned long product = a * b;
    return product + local[0] + local[1] + local[2];
}

int main(void) {
    long r;
    unsigned checksum;
    long q = divide(-1000000L, 7L, &r, &checksum);
    printf("frame=%ld,%ld,%u\n", q, r, checksum);
    q = divide(1000000L, -7L, &r, &checksum);
    printf("negative-divisor=%ld,%ld,%u\n", q, r, checksum);
    q = divide(-6L, 7L, &r, &checksum);
    printf("small-dividend=%ld,%ld,%u\n", q, r, checksum);
    printf("multiply=%lu\n", multiply(70000UL, 123UL));
    return 0;
}
