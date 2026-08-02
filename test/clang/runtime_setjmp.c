#include <stdio.h>
#include <setjmp.h>

static jmp_buf jb;
static int stage = 0;

int main(void) {
    if (setjmp(jb) == 0) {
        printf("A_SETJMP0\n");
        stage = 1;
        longjmp(jb, 1);
        printf("UNREACHABLE\n");
    } else {
        printf("B_AFTER_LONGJMP stage=%d\n", stage);
    }
    printf("C_DONE\n");
    return 0;
}
