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

/* ------------------------------------------------------------------------
 * Per-component timing harness (-DBENCH_COMPONENT=<fn> -DBENCH_COMPONENT_REPS=N)
 *
 * Runs a SINGLE stdcbench sub-benchmark exactly N times so its cost can be
 * isolated and z88dk-ticks-measured on its own, and so the per-component sums
 * reconcile against the whole-suite number (each sub-benchmark is called with
 * the same rep count the real driver uses: c90base 8x, c90lib 40x, per the
 * call-counter clock).  Each sub-benchmark writes its own slice of the shared
 * stdcbench_buffer before reading + self-validating, so it is correct standalone.
 *
 *   verify  (+cpm, no BENCH_TIMER): run N times, print COMPONENT OK/FAILED from
 *           stdcbench_error_count -- the correctness gate for the isolated run.
 *   timing  (+test, -DBENCH_TIMER): wrap the N calls in TIMER_START/TIMER_STOP.
 * -------------------------------------------------------------------------- */
#ifdef BENCH_COMPONENT
#define BENCH_STR_(x) #x
#define BENCH_STR(x)  BENCH_STR_(x)
extern void BENCH_COMPONENT(void);
#ifndef BENCH_COMPONENT_REPS
#define BENCH_COMPONENT_REPS 8u
#endif

int main(void)
{
	unsigned i;
#ifdef BENCH_TIMER
	intrinsic_label(TIMER_START);
	for (i = 0; i < (unsigned)BENCH_COMPONENT_REPS; i++)
		BENCH_COMPONENT();
	intrinsic_label(TIMER_STOP);
	if (stdcbench_error_count == 0xffffu)   /* keep the loop live */
		putchar(' ');
#else
	for (i = 0; i < (unsigned)BENCH_COMPONENT_REPS; i++)
		BENCH_COMPONENT();
	printf("component %s reps=%u errors=%u\n",
	       BENCH_STR(BENCH_COMPONENT), (unsigned)BENCH_COMPONENT_REPS,
	       stdcbench_error_count);
	printf(stdcbench_error_count == 0 ? "COMPONENT OK\n" : "COMPONENT FAILED\n");
#endif
	return (0);
}

#else /* !BENCH_COMPONENT : normal whole-suite driver */

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

	stdcbench_heap_selfcheck();   /* issue #40 guard; no-op off llvmz80 */
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

#endif /* BENCH_COMPONENT */
