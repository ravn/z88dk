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

## OPEN — 2 suites blocked; math suite MOSTLY GREEN (14/16, rest blocked on #278)

1. **math** — HEADER FIX LANDED (`ff60206bc2`): now **14/16 pass** under
   llvmz80 (was 11/16). sccz80/sdcc stay 16/16 (no regression).

   (1a) **sqrt/fmin/fmax/fabs — FIXED (z88dk header).** Under clang,
   `sys/compiler.h` defines `__STDC_ABI_ONLY`, so the `#ifndef __STDC_ABI_ONLY`
   fastcall/callee routing in `include/math/math_math32.h` is SKIPPED; the plain
   fallback decls carried NO calling convention, so clang used its default
   sdcccall(1) while the `cm32_sdcc_*` cores are sdcccall(0) -> mismatch. FIX:
   a new `__LLVMZ80`-gated `__MATH32_ABI == __smallc` annotates the four
   order-immune plain decls (1-arg sqrt/fabs, commutative 2-arg fmin/fmax).
   Verified at runtime: sqrt(4)~2 (within EPSILON 1e-6), fabs(-4)=4, fmin(4,2)=2,
   fmax(4,2)=4. Makefile Path B wiring (Math32-only + sf bridges +
   `-z80-float-sdcccall0`) committed in the same commit.

   (1b) **pow/fmod — BLOCKED on ravn/llvm-z80#278 (FILED 2026-08-03).** clang's
   `sdcccall(0)` pushes 2+ stack args in the OPPOSITE order to real SDCC.
   Dispositive differential (identical hand-written asm callee, only the compiler
   differs): `isub(1000,7)` -> SDCC **-993** (last C arg on top) vs clang
   **+993** (first C arg on top). Corroborated by the math cores: `pow(2,3)`->9
   (=3^2 swapped), `fmod(5.5,2)`->2. These two are left UNANNOTATED in the header
   (a header arg-swap would mask the bug and double-swap once #278 lands). Full
   repro in `tasks/bug-sdcccall0-multiarg-order-2026-08-03.md`.

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
