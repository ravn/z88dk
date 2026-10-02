#include <stdio.h>

/* Core ABI: HL=quotient, DE=remainder. Exercise both independent operations
 * and the fused operation with a live pointer argument and live results.
 */
static volatile int dividend = -30000, divisor = 7;
static volatile unsigned udividend = 50000, udivisor = 7;

__attribute__((noinline)) int signed_quotient(int a, int b) { return a / b; }
__attribute__((noinline)) int signed_remainder(int a, int b) { return a % b; }
__attribute__((noinline)) unsigned unsigned_quotient(unsigned a, unsigned b) {
    return a / b;
}
__attribute__((noinline)) unsigned unsigned_remainder(unsigned a, unsigned b) {
    return a % b;
}

__attribute__((noinline)) int signed_pair(int a, int b, int *r) {
    int q = a / b;
    *r = a % b;
    return q;
}

__attribute__((noinline)) unsigned unsigned_pair(unsigned a, unsigned b,
                                                 unsigned *r) {
    unsigned q = a / b;
    *r = a % b;
    return q;
}

int main(void) {
    int q, r;
    unsigned uq, ur;

    q = signed_quotient(dividend, divisor);
    r = signed_remainder(dividend, divisor);
    uq = unsigned_quotient(udividend, udivisor);
    ur = unsigned_remainder(udividend, udivisor);
    printf("separate=%d,%d,%u,%u\n", q, r, uq, ur);
    q = signed_pair(dividend, divisor, &r);
    uq = unsigned_pair(udividend, udivisor, &ur);
    printf("fused=%d,%d,%u,%u\n", q, r, uq, ur);
    q = signed_pair(30000, -7, &r);
    printf("negative-divisor=%d,%d\n", q, r);
    q = signed_pair(-6, 7, &r);
    printf("small-dividend=%d,%d\n", q, r);
    uq = unsigned_pair(65535u, 256u, &ur);
    printf("boundary=%u,%u\n", uq, ur);
    return 0;
}
