# z88dk × llvmz80 — test/suites triage 2026-08-03 (branch `llvmz80-float32-math32`)

Continuation of the same branch. Ran the full `test/suites` tree under
`-compiler=llvmz80` (toolchain works natively; env below) and triaged every
failing suite to root cause. 7 suites failed at suite granularity (the "~35"
figure was individual test binaries). All commits local only (no push/PR).

## Environment

    export PATH=/Users/ravn/z80/z88dk/bin:$PATH
    export ZCCCFG=/Users/ravn/z80/z88dk/lib/config
    export LLVMZ80EXE=/Users/ravn/z80/llvm-z80/build-macos/bin/clang

## RESOLVED this segment (4 suites now green, commits newest first)

- `4594d58da1` **sccz80: exclude 4 sccz80-ABI/UB files under llvmz80.**
  `sizeof.c` (sizeof(double)==6 + 3-byte far), `offsetof.c` (bare `test_s`
  tag + 6-byte-double offsets), `mult.c` (3*715827883 signed-32-bit-long
  overflow UB, #38 class), `rshift.c` (`0x8000000000000000LL` is *unsigned*
  per C so its `>>` is logical vs the signed `val>>` arithmetic). Filtered out
  of TARGET_Z80 only for COMPILER=llvmz80. Suite now 18 bins green.
- `5ce1b4f1a7` **sccz80/autoinit.c: compiler-aware asserts.** double_t[4] size
  32->16 (measured: clang-z80 +test double is 4 bytes, NOT 8) and the
  char[5]="HelloThere" overflow test uses memcmp(...,"Hello",5) under __LLVMZ80
  (C11 6.7.9p14: no terminator; sccz80 truncates to "Hell\0"). 7/7 green.
- `95c5d4f89f` **exclude classic #asm suites (zx, stdlib-newlib).** zx (all 13
  .c use `#asm INCLUDE`), stdlib test_newlib.bin (qsort_newlib.c `#asm DEFC`).
  clang has no `#asm` directive. filter-out in Makefile + stdlib `all` guard.
- `fc4f5263a5` **stdio/scanf.c: add missing `<string.h>`** (used strcmp, only
  #included stdio.h). test_scanf 7/7, test_sprintf 8/8.

Key measured fact: **under z88dk `+test`/genmath, clang-z80 `double` is 4 bytes**
(32-bit), not the 8-byte IEEE double it uses elsewhere. Verified with a probe.

## OPEN — 3 suites, each a REAL bug (not a test tweak), root-caused

1. **math** — LINK GAP CLOSED; now 11/16 pass. Remaining 5 (sqrt pow fmod
   fmin fmax) split into TWO distinct root causes (both verified via raw-byte
   probes under z88dk-ticks, 2026-08-03):

   (1a) **sqrt/fmin/fmax/fabs — z88dk HEADER gap (FIXABLE, owned fork).**
   Under clang, `sys/compiler.h` defines `__STDC_ABI_ONLY`, so ALL the
   `#ifndef __STDC_ABI_ONLY` blocks in `include/math/math_math32.h` (which for
   sccz80/sdcc `#define sqrt(x) sqrt_fastcall(x)` etc.) are SKIPPED. The plain
   fallback decls (`extern double_t __LIB__ sqrt(double_t)`) carry NO calling-
   convention attribute, so clang calls `_sqrt/_fmin/_fmax/_fabs` with its
   default sdcccall(1) while those symbols are the sdcccall(0) `cm32_sdcc_*`
   cores -> mismatch. VERIFIED FIX: mark these plain decls `__smallc`
   (=sdcccall(0)) OR route to the existing `*_fastcall` entry points under
   `__LLVMZ80`. Confirmed correct at runtime: sqrt(4)=0x3fffffff (~2, within
   EPSILON 1e-6), fabs(-4)=4.0 exact, fmin(4,2)=2 / fmax(4,2)=4 exact. These
   four are 1-arg or commutative -> immune to the (1b) order bug.

   (1b) **pow/fmod — BLOCKED on a VERIFIED clang-z80 sdcccall(0) multi-arg
   stack-order discrepancy (backend).** clang's `sdcccall(0)` pushes 2+ stack
   args in the OPPOSITE order to z88dk's `-compiler=sdcc` (real SDCC).
   Differential (identical hand-written asm callee `isub(a,b)=a-b`, only the
   compiler differs): `isub(1000,7)` -> SDCC **-993** (2nd C arg on top of
   stack) vs clang **+993** (1st C arg on top). Exact ±993, not garbage ->
   dispositive. Independently corroborated by the math cores: `pow_callee(2,3)`
   -> 9 (=3^2, swapped), correct only when args are hand-swapped
   `pow_callee(3,2)` -> 8; same for `fmod`. Even the dedicated `_callee`
   (z80_callee) entry points fail because the 2 args arrive reversed. NOTE the
   nuance (not yet spec-verified against SDCC docs): clang's sdcccall(0) DOES
   match z88dk's *hand-written* classic clib (str/mem work), and only diverges
   from *SDCC-compiled* sdcccall(0) code (the math32 cores). Which order is
   spec-correct per the SDCC manual is UNVERIFIED. A header arg-swap would be a
   workaround masking a compiler bug (forbidden by file-bugs-not-fixes, and it
   would double-swap once the backend is fixed). => file a backend/ABI bug at
   ravn/llvm-z80, but per `feedback_explain_before_filing` GET USER GO-AHEAD
   first. Until resolved, math suite stays BLOCKED (like regex/target_io); keep
   the Path B Makefile wiring (uncommitted) that gets 11/16.

2. **regex** — CONFIRMED miscompile of z88dk's regexp library under clang-z80.
   `regexec` prints `regexp(3): corrupted program` (its magic-byte sanity
   check on the compiled program fails). Source `libsrc/regex/` (regcomp/
   regexec). Repro: `test/suites/regex`, case `abracadabra$` vs
   `abracadabracadabra`. Needs root-cause: library-source portability vs
   backend codegen bug -> fix + ravn issue. Per `feedback_explain_before_filing`
   get user go-ahead before filing.

3. **target_io** — CONFIRMED fd-layer ABI failure under llvmz80. `fcntl_native.c`
   `tio_write->write()` returns wrong count (io_tests.c:75), `tio_open->open()`
   O_RDONLY returns fd<0 (:88). Likely `__z88dk_callee` / HL-vs-DE return-ABI
   bridge gap for open/creat/write/read/lseek under `+test`, same family as the
   md5sum fd-layer fix (include/fcntl.h `e8612ac2e4`). Needs per-function ABI
   verification + bridge fixes.

## Suites verified GREEN under llvmz80 (24 of 31)

string ctype stdio stdlib(classic) md5 + all benchmark suites (charbench
crcbench intbench ptrbench sieve rle sortbench queenbench searchbench
switchbench structbench vecbench maskbench strbench listbench interpbench
matrixbench hashbench fixedbench histbench lexbench) + sccz80. Excluded by
design: far, recordbench(#38), zx, stdlib-newlib.

## Constraints (standing)
- No push/PR/history-rewrite unless asked. Do not "fix" UB/ABI-specific tests by
  rewriting their logic (recordbench precedent, #38) — exclude or #ifdef.
- Every float/ABI bridge MUST be runtime-verified under ntvcm.
- Durable notes live in-project (this file), never ~/.claude/.
