/* Tests variadic function ABI under llvmz80 (__smallc stack convention):
 * va_list, va_start, va_arg, va_copy, va_end, and C23 variadics.
 *
 * NOTE: vsnprintf via va_list is NOT tested here because the z88dk classic
 * library's _vsnprintf.asm uses sdcccall(0) internally; passing a va_list
 * built by __smallc-compiled code across that ABI boundary misinterprets
 * the stack pointer and produces empty output. */
#include <stdarg.h>
#include <stdio.h>

__attribute__((noinline)) static int sum(int count, ...)
{
    va_list ap, copy;
    int result = 0;
    va_start(ap, count);
    va_copy(copy, ap);
    int first = va_arg(copy, int);
    va_end(copy);
    while (count--)
        result += va_arg(ap, int);
    va_end(ap);
    return first == 10 ? result : -1;
}

#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L
__attribute__((noinline)) static int c23_sum(int count, ...)
{
    va_list ap;
    va_start(ap);
    int result = 0;
    while (count--)
        result += va_arg(ap, int);
    va_end(ap);
    return result;
}
#endif

int main(void)
{
    for (int i = 0; i < 100; ++i) {
        if (sum(3, 10, 20, 30) != 60)
            return 1;
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L
        if (c23_sum(3, 10, 20, 30) != 60)
            return 2;
#endif
    }
    puts("ALL PASS");
    return 0;
}
