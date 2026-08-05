/* portme.c for z88dk +cpm / +test (all compilers).
 *
 * CP/M gives us a hosted C environment: crt0, printf/putchar and the standard
 * library come from the z88dk clib, so this file only supplies the three
 * stdcbench porting hooks.
 *
 * stdcbench_clock() is a pure call-counter (NOT a wall clock): each call
 * returns one more than the last.  With STDCBENCH_CLOCKS_PER_SEC small, this
 * makes every module run a fixed, deterministic number of iterations that is
 * identical across compilers; the actual cost is measured externally in
 * T-states with z88dk-ticks (see bench_main.c TIMER labels).  This is a
 * deliberate methodology change from the wall-clock "score" of the original
 * (documented per stdcbench RULES): we report cycles for a fixed workload,
 * which is more precise and fully deterministic on an emulator with no clock.
 */

#include <stdio.h>
#include "stdcbench.h"

/* Correctness gate: every module calls stdcbench_error() when an internal
 * checksum / validation fails.  We count them so the driver can print a
 * single deterministic OK/FAILED verdict (and any measured T-states are only
 * trustworthy when this stays zero). */
unsigned stdcbench_error_count;

void stdcbench_error(const char *message)
{
	stdcbench_error_count++;
	printf("ERROR: %s\n", message);
}

stdcbench_clock_t stdcbench_clock(void)
{
	static stdcbench_clock_t ticks;
	return (++ticks);
}
