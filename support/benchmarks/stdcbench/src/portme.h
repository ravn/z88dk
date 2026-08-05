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

/* Heap setup for the c90lib (standard-library) module, which uses
 * malloc/calloc/realloc/free (c90lib-lnlc allocates up to ~1.2 KB per graph;
 * c90lib-peep/htab grows a hash table via realloc).  Under ravn/llvm-z80 +cpm
 * the classic clib needs an explicit heap: without one, malloc returns NULL,
 * the kernels take their "malloc() failed" error path repeatedly and the run
 * neither validates nor finishes in a sane ticks budget.
 *
 * The natural choice would be the WHOLE free TPA -- everything from the end of
 * BSS up to SP (the bottom of BDOS) -- via the crt's dynamic heap models
 * (CRT_STACK_SIZE, or -DAMALLOC in crt_init_heap.inc).  That is BLOCKED for now
 * by a classic-malloc/llvmz80 heap-init bug: every dynamic (BSS_END..SP) model
 * fails the full run (CRT_STACK_SIZE registers a bogus ~200 KB arena starting
 * mid-program -> address wraparound -> warm-boot loop; -DAMALLOC registers a
 * seemingly-sane ~29 KB arena yet still takes the malloc()-failed path), while
 * a FIXED BSS heap of the SAME size works.  Tracked in ravn/z88dk#40.
 *
 * Until that is fixed, use a fixed BSS heap (CLIB_MALLOC_HEAP_SIZE).  24 KB
 * covers the benchmark's peak live set with margin: fixed heaps of 16/20/24/28
 * KB all PASS (score 480); 32 KB makes the image large enough that the
 * downward stack collides with the heap and the run hangs, so 24 KB leaves
 * headroom on both sides.  Other compilers manage their own heap, so this is
 * llvmz80-only. */
#if defined(__LLVMZ80)
#pragma define CLIB_MALLOC_HEAP_SIZE=24576
#endif

/* Module selection.
 *
 * stdcbench 0.8 ships only TWO implemented modules -- c90base and c90lib.
 * c90float and c90double are upstream placeholders marked "NOT YET IMPLEMENTED!"
 * in src/README (their c90float()/c90double() bodies just `return 0`; the
 * floating-point module is item #1 in src/TODO).  They are therefore left
 * `#undef`ed here because there is nothing to run -- NOT because a toolchain
 * limitation disabled them.  This means c90base + c90lib IS the full implemented
 * stdcbench 0.8 suite; "full coverage" needs no float runtime.  (llvmz80 double
 * support does exist separately -- ../../../llvmz80-softfloat, LLVMZ80RTLIB --
 * but stdcbench never calls it.)
 *
 * Module selection can be overridden from the build (so lanes that hit a
 * toolchain limitation can drop a module symmetrically and comparably):
 *   -DSTDCBENCH_DISABLE_C90LIB   omit the c90lib (standard-library) module.
 */
#define C90BASE
#undef  C90FLOAT   /* upstream stub: "NOT YET IMPLEMENTED!" (src/README) */
#undef  C90DOUBLE  /* upstream stub: "NOT YET IMPLEMENTED!" (src/README) */
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
