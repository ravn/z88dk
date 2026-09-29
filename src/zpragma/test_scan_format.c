#include <stdio.h>
#include <inttypes.h>
#include "zpragma_internal.h"

static int tests_run = 0, tests_failed = 0;

static void check(const char *desc, uint64_t got, uint64_t want)
{
    tests_run++;
    if (got != want) {
        printf("FAIL [%s]: got 0x%08" PRIx64 ", want 0x%08" PRIx64 "\n",
               desc, got, want);
        tests_failed++;
    }
}

/* scan_format_literal takes a pointer into preprocessed source, so the
 * input string must include the surrounding quotes as the preprocessor
 * leaves them, e.g. "\"%d\"" for a format string "%d". */
#define SFL(s)   scan_format_literal(s, printf_formats)
#define SFLSC(s) scan_format_literal(s, scanf_formats)
#define PFS(s)   parse_format_string((char *)(s), printf_formats)

int main(void)
{
    /* plain specifiers */
    check("%d",  SFL("\"%d\""),  0x01);
    check("%u",  SFL("\"%u\""),  0x02);
    check("%x",  SFL("\"%x\""),  0x04);
    check("%s",  SFL("\"%s\""),  0x200);
    check("%c",  SFL("\"%c\""),  0x400);
    check("%f",  SFL("\"%f\""),  0x4000000);

    /* length modifier — must NOT set flags bit */
    check("%ld", SFL("\"%ld\""), 0x1000);
    check("%lf", SFL("\"%lf\""), 0x4000000);

    /* width/precision → bit 30 (flags handling) */
    check("%6d",   SFL("\"%6d\""),   0x40000001);
    check("%6.1f", SFL("\"%6.1f\""), 0x44000000);
    check("%-6d",  SFL("\"%-6d\""),  0x40000001);
    check("%*d",   SFL("\"%*d\""),   0x40000001);

    /* multiple specifiers */
    check("%d %s", SFL("\"%d %s\""), 0x201);
    check("%d %f", SFL("\"%d %f\""), 0x4000001);

    /* adjacent string literal concatenation */
    check("adj %d %s", SFL("\"%d\" \"%s\""), 0x201);

    /* escaped quote inside literal must not end the scan */
    check("esc quote", SFL("\"%d\\\"ok\\\"%s\""), 0x201);

    /* %% is a literal percent, not a specifier */
    check("%%", SFL("\"%%\""), 0x00);

    /* empty string */
    check("empty", SFL("\"\""), 0x00);

    /* scanf specifiers */
    check("scanf %d", SFLSC("\"%d\""),     0x01);
    check("scanf %s", SFLSC("\"%s\""),     0x200);
    check("scanf %[", SFLSC("\"%[a-z]\""), 0x200000);

    /* parse_format_string (pragma notation: space-separated, no %/quotes needed) */
    check("pfs d",    PFS("d"),    0x01);
    check("pfs f",    PFS("f"),    0x4000000);
    check("pfs lf",   PFS("lf"),   0x4000000);
    check("pfs ld",   PFS("ld"),   0x1000);
    check("pfs d s",  PFS("d s"),  0x201);
    check("pfs 6.1f", PFS("6.1f"), 0x44000000);

    if (tests_failed == 0)
        printf("PASS: %d tests\n", tests_run);
    else
        printf("FAILED: %d/%d\n", tests_failed, tests_run);
    return tests_failed ? 1 : 0;
}
