Dhrystone 2.1 -- zcc +cpm/+test -compiler=llvmz80 (ravn/llvm-z80 backend)
========================================================================

Benchmark version
-----------------
  Dhrystone Benchmark, C, Version 2.1
  Date:    May 25, 1988
  Author:  Reinhold P. Weicker
  Original (Ada) published in Communications of the ACM vol. 27 no. 10
  (Oct. 1984), pp. 1013-1030.  C/2.1 by Rick Richardson & Reinhold Weicker.
The dhry_1.c / dhry_2.c / dhry.h here are byte-for-byte the same sources as
../z88dk-classic and ../sdcc (the z88dk tree copy of the 2.1 release); this
directory only adds a Makefile + readme for the llvmz80 lane.

llvmz80 is the ravn/llvm-z80 GlobalISel clang: a z80 (16-bit) target with a
register-passing ABI, distinct from the eZ80 ez80-clang the generic __CLANG
path was written for.  This directory drives the same Dhrystone 2.1 sources
as ../z88dk-classic and ../sdcc, but through llvmz80.

Two z88dk-native measurement paths (no source edits to dhry_*.c/dhry.h):

  make benchmark
      +test -DTIMER build.  The z88dk intrinsic_label(TIMER_START/STOP)
      markers (dhry.h) become bare labels via include/intrinsic.h's __CLANG
      branch and the copt rule in lib/llvmz80/llvmz80_rules.1.  z88dk-ticks
      then counts cycles between the two label addresses (-start/-end).  No
      printf, no float -- a clean cycle count -> DMIPS.

  make verify [NTVCM=/path/to/ntvcm]
      +cpm -DPRINTF build run under ntvcm to confirm the self-validating
      "should be:" checks all pass.  dhry.h forces the %f printf converter
      (CLIB_OPT_PRINTF bit 0x04000000) whenever PRINTF is defined, but %f is
      only used under TIMEFUNC; llvmz80 has no float-math lib wired, so the
      Makefile drops that bit with -pragma-define:CLIB_OPT_PRINTF=0x00000601.

Reference numbers (llvm-z80 main, 2026-07-11, @ 4 MHz Z80, 20000 runs):

  llvmz80  -O2   :  8461 cycles/run   0.2691 DMIPS
  sdcc     -SO3  : 12158 cycles/run   0.1872 DMIPS   (../z88dk-classic)

Cross-machine caveat: the DMIPS number assumes a 4 MHz Z80; adjust CPUFREQ in
the Makefile for other clocks.


Why llvmz80 is ~30% faster than sdcc here
-----------------------------------------
Both lanes link the SAME z88dk classic C library (+test), so this is NOT a
library effect: the struct assignments compile to LDIR in both, and the win
comes entirely from the compiled Dhrystone C.  Comparing the generated asm
(dhry_1.c + dhry_2.c, sdcc -SO3 vs llvmz80 -O2) shows two mechanisms:

  1. Register calling convention + far fewer stack frames.
     sdcc builds an IX stack frame in 6 functions and re-reads each parameter
     from memory via (ix+n) on every use; llvmz80 builds only 2 (main and
     Proc_8, which hold the big local arrays).  The small functions called on
     every iteration (Proc_6/7, Func_1/2/3) run frame-less under llvmz80 with
     arguments in HL/DE, saving the per-call push ix / ld ix,0 / add ix,sp /
     pop ix and the associated memory traffic.  Library calls likewise use the
     register fastcall entry (___strcpy) instead of sdcc's stack-based
     callee-cleanup entry (_strcpy_callee).

  2. Stronger middle-end (LLVM) optimization.
     In Func_2, llvmz80 inlines the whole of Func_1 and deletes the trivial
     one-trip `for (Int_Loc = 2; Int_Loc <= 2; ++Int_Loc)` loop; sdcc keeps
     the loop and emits a real `call _Func_1`.  Measured over both TUs sdcc
     has 2 real Func_1 call sites, llvmz80 only 1.

Honest caveat: the total STATIC instruction count is essentially identical
(686 asm instruction lines each).  llvmz80 does not emit fewer instructions --
it emits cheaper-to-execute ones on the hot path (register moves rather than
(ix+n) memory access, one fewer call per iteration, no per-call frame).  The
gain is dynamic, not code size.  The two mechanisms above are read directly
from the asm (verified); the exact split of the ~3700 cycle/run difference
between them was not measured per-function (that would need z88dk-ticks
-start/-end around individual calls) and is inferred from Dhrystone making
~13 calls per iteration, most of which are now frame-less.

Aside: llvmz80's Func_2 contains a `jr` self-loop on the branch where the two
compared characters are equal -- LLVM exploiting the fact that the real
Dhrystone data never takes that path (the +cpm -DPRINTF `make verify` run
passes all 20 self-checks).  This aggressive use of undefined behaviour is
part of what lets it emit the tighter code.
