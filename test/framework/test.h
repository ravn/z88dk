

#ifndef TEST_H
#define TEST_H


#include <stdlib.h>   /* exit() — else a suite's exit(res) warns implicit-int */

#ifndef MAX_TESTS
#define MAX_TESTS 50
#endif


#define ASSERT(c) Assert_real((c), __FILE__, __LINE__, #c)
#define Assert(r,m) Assert_real((r), __FILE__, __LINE__, (m))
#define assertEqual(a,b) Assert_real((a) == (b),  __FILE__, __LINE__, #a  "== "  #b)
#define assertNotEqual(a,b) Assert_real((a) != (b),  __FILE__, __LINE__, #a  "!= "  #b)
extern void         Assert_real(int result, char *file, int line,  char *message);


extern int          suite_run(void);
extern void         suite_setup(char *suitename);
extern void         suite_add_fixture(void (*setup)(void), void (*teardown)(void));
#define suite_add_test(f) suite_add_test_real("" # f "", f)
extern void         suite_add_test_real(char *testname, void (*test)(void));

/* XFAIL: register a test that is EXPECTED to fail (e.g. a known, filed bug).
 * An expected failure is reported "...xfail" and does NOT fail the suite; if
 * such a test unexpectedly PASSES it is reported "...XPASS" and DOES fail the
 * suite, so the marker gets removed once the underlying bug is fixed. */
#define suite_add_xfail_test(f) suite_add_xfail_test_real("" # f "", f)
extern void         suite_add_xfail_test_real(char *testname, void (*test)(void));


#endif
