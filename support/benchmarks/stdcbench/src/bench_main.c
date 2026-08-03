/* z88dk driver for stdcbench (+cpm verify lane and +test benchmark lane).
 *
 * Two build modes, selected by -DBENCH_TIMER:
 *
 *   verify  (+cpm, no BENCH_TIMER): run every module, print the per-module and
 *           final scores, and print a single OK/FAILED line derived from the
 *           stdcbench_error_count.  Run under an emulator (ntvcm); this is the
 *           correctness gate.
 *
 *   benchmark (+test, -DBENCH_TIMER): wrap the stdcbench() call in the z88dk
 *           intrinsic_label(TIMER_START/TIMER_STOP) markers so z88dk-ticks can
 *           count the T-states of the fixed-iteration workload.  No printf on
 *           the timed path.
 *
 * The workload is deterministic (portme.c's call-counter clock), so both lanes
 * execute exactly the same amount of work; verify proves it is correct, and
 * benchmark measures what it costs.
 */

#include <stdio.h>
#include "stdcbench.h"

extern unsigned stdcbench_error_count;

#ifdef BENCH_TIMER
#include <intrinsic.h>
#endif

int main(void)
{
	unsigned long score;

#ifdef BENCH_TIMER
	intrinsic_label(TIMER_START);
	score = stdcbench();
	intrinsic_label(TIMER_STOP);
	/* keep the result live so the whole call is not dead-code-eliminated */
	if (score == 0xffffffffUL)
		putchar(' ');
#else
	printf("\n%s\n", stdcbench_name_version_string);

	score = stdcbench();

#ifdef C90BASE
	printf("stdcbench c90base score: %lu\n", c90base_score);
#endif
#ifdef C90LIB
	printf("stdcbench c90lib score: %lu\n", c90lib_score);
#endif
	printf("stdcbench final score: %lu\n", score);

	if (stdcbench_error_count == 0)
		printf("STDCBENCH OK\n");
	else
		printf("STDCBENCH FAILED errors=%u\n", stdcbench_error_count);
#endif

	return (0);
}
