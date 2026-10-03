#include <stdio.h>
#include <stdlib.h>

static int values[] = {7, -3, 1, 7, 0};

__z88dk_callback int compare_ints(const void *left, const void *right) {
    int a = *(const int *)left;
    int b = *(const int *)right;
    return (a > b) - (a < b);
}

int main(void) {
    qsort(values, 5, sizeof(values[0]), compare_ints);
    printf("qsort %d,%d,%d,%d,%d\n",
           values[0], values[1], values[2], values[3], values[4]);
    return 0;
}
