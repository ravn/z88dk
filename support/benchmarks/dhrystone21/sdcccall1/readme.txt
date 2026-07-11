Dhrystone 2.1 -- zcc +test/+cpm -compiler=sdcc with --sdcccall 1
===============================================================

This lane compiles the SAME Dhrystone 2.1 sources as ../z88dk-classic and
../sdcc, but forces SDCC's version-1 calling convention (--sdcccall 1):
8-bit return in A, 16-bit in DE, 24-bit in LDE, 32-bit in HLDE, arguments in
registers.  ../z88dk-classic uses z88dk's default version-0 convention
(stack frame via IX, callee cleanup).  This lane exists to separate "how much
of a compiler's Dhrystone score is the calling convention" from "how much is
the middle-end / register allocator".

Why a PATH shim is needed
-------------------------
Upstream SDCC already defaults z80 to --sdcccall 1, but z88dk overrides it
back to version 0 because its entire precompiled clib + crt0 are built
version 0.  zcc deliberately does NOT forward --sdcccall to zsdcc (neither
-Cc--sdcccall=1 nor --sdcccall=1 reaches codegen -- verified).  The Makefile
therefore injects the flag with a one-line PATH shim on z88dk-zsdcc,
generated at build time from `command -v z88dk-zsdcc` (no absolute path is
committed), while leaving the rest of the zcc pipeline (sdcc-dialect bridge,
copt rules, library selection, crt0) untouched.

Why this is safe (no ABI mismatch)
----------------------------------
z88dk's library headers pin each libc function to its own calling convention
(e.g. string.h: `strcpy ... __smallc __z88dk_callee`), so calls from the
--sdcccall 1 user code into the version-0 library still use the correct,
header-declared convention.  crt0 ignores main()'s return value.  SDCC emits
`warning 296: non-default sdcccall specified, but default stdlib or crt0`;
here it is benign, and `make verify` confirms all 20 self-validation
"should be:" checks pass under ntvcm.

Targets
-------
  make benchmark              +test -DTIMER build; z88dk-ticks -start/-end.
  make verify [NTVCM=/path]   +cpm -DPRINTF self-validating run under ntvcm.
  make clean

The CLIB_OPT_PRINTF override in the verify build drops the spurious %f printf
converter that dhry.h forces via `#pragma output` under PRINTF (%f is only
used under TIMEFUNC, which is off), matching the ../llvmz80 lane.

Reference number (2026-07-11, @ 4 MHz Z80, 20000 runs)
------------------------------------------------------
  sdcc --sdcccall 1 -SO3 : 11044 cycles/run   0.2061 DMIPS
For comparison (same sources, same harness):
  llvmz80 -O2            :  8461 cycles/run   0.2691 DMIPS   (../llvmz80)
  sdcc --sdcccall 0 -SO3 : 12158 cycles/run   0.1872 DMIPS   (../z88dk-classic)
