




#include "string_tests.h"

#ifdef __LLVMZ80
// clang/llvmz80 exposes stricmp/strcasecmp as default-convention (sdcccall(1))
// inline wrappers (see string.h __ZPROTO2), so the pointer that holds them must
// use the default convention, not __smallc.  sccz80/sdcc keep the __smallc
// library convention below.
static int (*func)(const char *x,const  char *y);
#else
static int (*func)(const char *x,const  char *y) __smallc;
#endif

void stricmp_equal_lower()
{
    Assert(func("equal","equal") == 0, "Should be == 0");
}

void stricmp_equal_upper()
{
    Assert(func("EQUAL","EQUAL") == 0, "Should be == 0");
}

void stricmp_equal_mixed()
{
    Assert(func("EqUaL","eQuAl") == 0, "Should be == 0");
}

void stricmp_less()
{
    Assert(func("EQUAL","equam") < 0, "Should be < 0");
}

void stricmp_greater()
{
    Assert(func("equam","EQUAL") > 0, "Should be > 0");
}


int test_stricmp()
{
    suite_setup("Stricmp Tests");

    func = stricmp;

    suite_add_test(stricmp_equal_lower);
    suite_add_test(stricmp_equal_upper);
    suite_add_test(stricmp_equal_mixed);
    suite_add_test(stricmp_less);
    suite_add_test(stricmp_greater);

    return suite_run();
}

int test_strcasecmp()
{
    suite_setup("Strcasecmp Tests");

    func = strcasecmp;

    suite_add_test(stricmp_equal_lower);
    suite_add_test(stricmp_equal_upper);
    suite_add_test(stricmp_equal_mixed);
    suite_add_test(stricmp_less);
    suite_add_test(stricmp_greater);

    return suite_run();
}
