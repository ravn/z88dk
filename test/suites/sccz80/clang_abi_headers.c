#include "test.h"
#include <sys/compiler.h>
#include <stdarg.h>
#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int fn_smallc(int a, int b) __smallc
{
    return a - b;
}

static int fn_stdc(int a, int b) __stdc
{
    return a + b;
}

static int cmp_callback(const void *a, const void *b) __runtime_library_callback
{
    return *(const int *)a - *(const int *)b;
}

void test_calling_conventions(void)
{
    Assert(fn_smallc(10, 3) == 7, "fn_smallc(10, 3) == 7");
    Assert(fn_stdc(10, 3) == 13, "fn_stdc(10, 3) == 13");
}

#if defined(__LLVMZ80)
static int sum_varargs(int count, ...)
{
    va_list ap;
    va_start(ap, count);
    int s = 0;
    int i;
    for (i = 0; i < count; i++) {
        s += va_arg(ap, int);
    }
    va_end(ap);
    return s;
}

void test_varargs(void)
{
    int s = sum_varargs(4, 10, 20, 30, 40);
    Assert(s == 100, "sum_varargs == 100");
}
#else
void test_varargs(void)
{
    va_list ap;
    (void)ap;
    Assert(1, "stdarg types defined");
}
#endif

void test_qsort_callback(void)
{
    int arr[4] = { 40, 10, 30, 20 };
    qsort(arr, 4, sizeof(int), cmp_callback);
    Assert(arr[0] == 10, "arr[0] == 10");
    Assert(arr[1] == 20, "arr[1] == 20");
    Assert(arr[2] == 30, "arr[2] == 30");
    Assert(arr[3] == 40, "arr[3] == 40");
}

void test_strncat_return(void)
{
    char buf[32];
    strcpy(buf, "foo");
    char *ret = strncat(buf, "bar", 3);
    Assert(ret == buf, "strncat returns dst buffer pointer");
    Assert(strcmp(buf, "foobar") == 0, "buf is foobar");
}

void test_setjmp_roundtrip(void)
{
    jmp_buf jb;
    volatile int stage = 0;
    int rv = setjmp(jb);
    if (rv == 0) {
        stage = 1;
        longjmp(jb, 42);
    } else {
        Assert(rv == 42, "longjmp rv == 42");
        Assert(stage == 1, "stage == 1");
    }
}

int suite_clang_abi_headers(void)
{
    suite_setup("Clang ABI Headers Tests");
    suite_add_test(test_calling_conventions);
    suite_add_test(test_varargs);
    suite_add_test(test_qsort_callback);
    suite_add_test(test_strncat_return);
    suite_add_test(test_setjmp_roundtrip);
    return suite_run();
}

int main(void)
{
    return suite_clang_abi_headers();
}
