#include <stdio.h>

/* Unused result, constant format and dynamic string permit printf -> puts
 * folding, except that the two z88dk declarations have different ABIs. */
__attribute__((noinline))
void print_lines(const char *direct, const char *formatted) {
    puts(direct);
    printf("%s\n", formatted);
}

int main(void) {
    print_lines("direct puts", "retained printf");
    return 0;
}
