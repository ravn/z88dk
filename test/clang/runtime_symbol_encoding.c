#include <stdio.h>

volatile int test_counter = 1;
volatile int L4_test7_counter = 10;

__attribute__((noinline)) int test(void) {
    static volatile int counter = 100;
    return ++counter + test_counter + L4_test7_counter;
}

int main(void) {
    int first = test();
    int second = test();
    puts(first == 112 && second == 113 && test_counter == 1 &&
                 L4_test7_counter == 10
             ? "PASS"
             : "FAIL");
    return 0;
}
