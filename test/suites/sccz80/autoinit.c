#include "test.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void test_string_array(void)
{
     char    string[] = "HelloThere";

     assertEqual(0, strcmp(string,"HelloThere"));
     assertEqual(11, sizeof(string));
}

void test_string_array_overflow(void)
{
     char    string[5] = "HelloThere";

     assertEqual(5, sizeof(string));
#ifdef __LLVMZ80
     /* Standard C (C11 6.7.9p14): a char[N] initialised from a longer string
        literal takes the first N characters with NO terminator, so `string`
        holds the 5 bytes "Hello" (unterminated). clang follows the standard;
        sccz80 instead truncates to "Hell\0". strcmp here would read past the
        array, so compare the well-defined 5-byte content directly. */
     assertEqual(0, memcmp(string,"Hello",5));
#else
     assertEqual(0, strcmp(string,"Hell"));
#endif
}


void test_string_array_underflow(void)
{
     char    string[20] = "HelloThere";

     assertEqual(0, strcmp(string,"HelloThere"));
     assertEqual(20, sizeof(string));
}

void test_int_array(void)
{
    int numbers[] = { 1, 2, 3, 4};

    assertEqual(8, sizeof(numbers));
    assertEqual(1, numbers[0]);
}

void test_double_array(void)
{
    double_t numbers[] = { 1.0, 2.0, 3.0, 4.0};

#ifdef __LLVMZ80
    /* Under z88dk's +test/genmath config clang-z80 uses a 4-byte (32-bit)
       double, so 4 elements = 16; sccz80's default double is the 6-byte
       48-bit format, hence 24 there. (Measured, not assumed.) */
    assertEqual(16, sizeof(numbers));
#else
    assertEqual(24, sizeof(numbers));
#endif
    assertEqual(1.0, numbers[0]);
}


struct ts {
    long  l;
    int   i;
    char *s;
};

void test_struct(void)
{
    struct ts val = { 0xdeadbeef, 23, "Hello"};

    assertEqual(8, sizeof(val));
    assertEqual(0xdeadbeef, val.l);
    assertEqual(23, val.i);
    assertEqual(0, strcmp(val.s,"Hello"));
}

void test_struct_array(void)
{
    struct ts val[] = {
        { 0xdeadbeef, 23, "Hello"},
        { 0x5ca1ab1e, 12, "Goodbye" }
    };

    assertEqual(16, sizeof(val));
    assertEqual(0xdeadbeef, val[0].l);
    assertEqual(23, val[0].i);
    assertEqual(0, strcmp(val[0].s,"Hello"));

    assertEqual(0x5ca1ab1e, val[1].l);
    assertEqual(12, val[1].i);
    assertEqual(0, strcmp(val[1].s,"Goodbye"));
}


int suite_autoinit()
{
    suite_setup("Auto aggregate variables");

    suite_add_test(test_string_array);
    suite_add_test(test_string_array_overflow);
    suite_add_test(test_string_array_underflow);
    suite_add_test(test_int_array);
    suite_add_test(test_double_array);
    suite_add_test(test_struct);
    suite_add_test(test_struct_array);

    return suite_run();
}


int main(int argc, char *argv[])
{
    int  res = 0;

    res += suite_autoinit();

    exit(res);
}
