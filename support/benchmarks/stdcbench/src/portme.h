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
 *
 * Consequence: the reported "score" is a deterministic CONSTANT here
 * (SECONDS*10 per module -> c90base 80, c90lib 400, final 480), NOT a speed
 * or instruction figure -- it only certifies completion + self-validation.
 * Full derivation and the real-timing (T-state) recipe: ../RESULTS.md.
 */

typedef unsigned long stdcbench_clock_t;

#define STDCBENCH_CLOCKS_PER_SEC 1

/* Heap setup for the c90lib (standard-library) module, which uses
 * malloc/calloc/realloc/free (c90lib-lnlc allocates up to ~1.2 KB per graph;
 * c90lib-peep/htab grows a hash table via realloc).  Under ravn/llvm-z80 +cpm
 * the classic clib needs a heap: without one, malloc returns NULL, the kernels
 * take their "malloc() failed" error path repeatedly and the run neither
 * validates nor finishes in a sane ticks budget.
 *
 * We use the WHOLE free TPA -- everything from the end of BSS up to just below
 * SP (the bottom of BDOS) -- via the crt's dynamic CRT_STACK_SIZE model.  At
 * runtime +cpm sets SP from word@6 (the BDOS base) and the crt registers the
 * heap as [__BSS_END_tail .. SP - CRT_STACK_SIZE]; the stack grows downward
 * from SP into the reserved CRT_STACK_SIZE region.  Layout:
 *   [program][BSS][heap -> ... gap ... <- stack][BDOS]
 * Nothing is hardcoded -- it adapts to whatever machine's BDOS ceiling.
 *
 * The reserve is 2 KB: the benchmark's measured peak stack use is ~780 B, so
 * 2048 gives ~2.5x margin while leaving 20+ KB of heap under a typical BDOS.
 *
 * (This dynamic model was previously BLOCKED by ravn/z88dk#40 -- a classic-CRT
 * section-ordering bug where qsort's __stdlib_quicksort_size_lsb overlapped the
 * dynamic heap's free-list header, corrupting it on the first qsort.  Fixed by
 * adding `SECTION bss_stdlib` to lib/crt/classic/crt_section_bss.inc.  Other
 * compilers manage their own heap, so this is llvmz80-only.) */
#if defined(__LLVMZ80)
#pragma define CRT_STACK_SIZE=2048
#endif

/* Module selection.
 *
 * stdcbench 0.8 ships only TWO implemented modules -- c90base and c90lib.
 * c90float and c90double are upstream placeholders marked "NOT YET IMPLEMENTED!"
 * in src/README (their c90float()/c90double() bodies just `return 0`; the
 * floating-point module is item #1 in src/TODO).  They are therefore left
 * `#undef`ed here because there is nothing to run -- NOT because a toolchain
 * limitation disabled them.  This means c90base + c90lib IS the full implemented
 * stdcbench 0.8 suite; "full coverage" needs no float runtime.  (llvmz80
 * double support does exist separately -- 32-bit IEEE-754 via the auto-linked
 * llvmz80_fmath.lib math32 bridge with --math32 -- but stdcbench never calls
 * it.)
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
 * z88dk qsort/bsearch core invokes the comparator with the classic-lib callback
 * convention, which <stdlib.h> carries as __z88dk_callback (= sdcccall(0) for
 * llvmz80, empty for sccz80/sdcc -- see <sys/compiler.h>).  A comparator passed
 * to qsort MUST be declared with this qualifier or it is miscalled at runtime.
 * Applied to the c90lib-lnlc.c comparator; harmless (expands empty) elsewhere. */
#if defined(__LLVMZ80)
#define STDCBENCH_CMP_CONV __z88dk_callback
#else
#define STDCBENCH_CMP_CONV
#endif

/* Issue #40 regression guard (llvmz80 dynamic-heap model).  qsort writes its
 * element-size lowest-set-bit to the BSS scratch var __stdlib_quicksort_size_lsb;
 * if the classic CRT ever drops `SECTION bss_stdlib` from crt_section_bss.inc
 * again, that var overlaps the dynamic heap's free-list header at __BSS_END_tail
 * and the FIRST qsort corrupts it -> the next malloc returns NULL.  This runs a
 * tiny malloc/qsort(all-equal,size=1)/malloc at startup and aborts loudly if the
 * overlap has regressed, instead of failing deep inside a kernel with a bare
 * "malloc() failed".  Cheap; a no-op on other compilers. */
void stdcbench_heap_selfcheck(void);
