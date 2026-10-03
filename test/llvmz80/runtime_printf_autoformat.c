#include <stdio.h>
#include <string.h>

int main(void) {
    char buf[48];

    snprintf(buf, sizeof buf, "v=%6.1f|d=%d|s=%s", 3.5, 42, "ok");
    if (strcmp(buf, "v=   3.5|d=42|s=ok") != 0) {
        printf("FAIL fmt [%s]\n", buf);
        return 1;
    }

    snprintf(buf, sizeof buf, "%f", 2.0);
    if (strcmp(buf, "2.000000") != 0) {
        printf("FAIL bare %%f [%s]\n", buf);
        return 1;
    }

    printf("PASS autoformat\n");
    return 0;
}
