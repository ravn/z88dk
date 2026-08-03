/* portme.h for z88dk +cpm / +test targets (all compilers).
 *
 * Timing model: unlike a real board, we do NOT sample a wall clock here.
 * stdcbench's driver loops each module until stdcbench_clock() advances by
 * SECONDS = STDCBENCH_CLOCKS_PER_SEC * N.  We make stdcbench_clock() a pure
 * call-counter (see portme.c), so the loop executes a FIXED, deterministic
 * iteration count that is identical across every compiler.  The real metric
 * is the T-state count for that fixed workload, measured externally with
 * z88dk-ticks between the TIMER_START/TIMER_STOP labels in bench_main.c.
 *
 * STDCBENCH_CLOCKS_PER_SEC therefore just scales the fixed iteration count:
 *   c90base iterations = STDCBENCH_CLOCKS_PER_SEC * 8
 *   c90lib  iterations = STDCBENCH_CLOCKS_PER_SEC * 40
 * Keep it small so the emulated run finishes in a sane ticks budget while
 * still exercising each module enough times to be representative.
 */

typedef unsigned long stdcbench_clock_t;

#define STDCBENCH_CLOCKS_PER_SEC 1

/* Integer-only modules: exercise codegen + the standard library, no float.
 *
 * Module selection can be overridden from the build (so lanes that hit a
 * toolchain limitation can drop a module symmetrically and comparably):
 *   -DSTDCBENCH_DISABLE_C90LIB   omit the c90lib (standard-library) module.
 */
#define C90BASE
#undef  C90FLOAT
#undef  C90DOUBLE
#ifndef STDCBENCH_DISABLE_C90LIB
#define C90LIB
#endif

/* qsort()/bsearch() comparator calling convention.  Under ravn/llvm-z80 the
 * z88dk qsort core calls the comparator with the __smallc (sdcccall(0), stack)
 * convention -- see include/stdlib.h -- so a comparator passed to qsort MUST
 * be declared __smallc or it is miscalled at runtime.  Every other compiler
 * uses its default convention, so the qualifier is empty there.  Applied to
 * the c90lib-lnlc.c comparator; harmless (expands empty) elsewhere. */
#if defined(__LLVMZ80)
#define STDCBENCH_CMP_CONV __smallc
#else
#define STDCBENCH_CMP_CONV
#endif
