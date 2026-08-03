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

## OPEN — 1 suite blocked (target_io: plan ready); regex FILED #39; math GREEN via XFAIL (#278)

1. **math** — GREEN under llvmz80 (via XFAIL). `test_math32`: **16 run,
   14 passed, 0 failed, 2 xfail** (runtest exits 0). sdcc/sccz80 stay 16/16.

   (1a) **sqrt/fmin/fmax/fabs — FIXED (z88dk header, `ff60206bc2`).** Under clang,
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
   repro in `tasks/bug-sdcccall0-multiarg-order-2026-08-03.md`. Marked XFAIL in
   `math.c` under `__LLVMZ80` (`suite_add_xfail_test`, framework support added in
   `e84b32907e`) so the suite is green; an XPASS will signal #278 is fixed and
   the marker should be removed.

2. **regex** — ROOT-CAUSED + FILED as **ravn/z88dk#39** (2026-08-03). NOT a
   backend miscompile: it is the stack-ABI-vs-register-ABI class (#22/#26/fcntl).
   `include/regexp.h` declares `regexec`/`regsub` `__smallc` (stack) for native,
   but under clang routes them via `__ZPROTO2`/`__ZPROTO3` (reversed-arg, DEFAULT
   sdcccall(1) register convention). The library object `regex/obj/z80/cimpl/
   regexp.o` is the sccz80-built `__smallc` STACK worker, and `test.map` shows
   `___regexec = _regexec = $175E` (clang's symbol is a bare alias of the stack
   worker, NO register->stack bridge). Call-site asm confirms clang passes
   HL=string, DE=prog in REGISTERS (`jp ___regexec`); the stack worker reads args
   off the stack -> garbage `prog` -> `prog->program[0] != MAGIC (0234)` ->
   `regerror("corrupted program")`. `regcomp` is 1-arg -> immune (compiles fine,
   only matching fails). Passes sccz80+sdcc, fails only llvmz80. Fix direction
   (not done): reversed-arg `__smallc` header entries a la the fcntl md5sum fix.

3. **target_io** — RE-INVESTIGATED THOROUGHLY 2026-08-03; PLAN in
   `tasks/plan-target_io-llvmz80-2026-08-03.md`. Three verified findings:
   (a) **Recipe is RED for ALL compilers** (harness bug, not compiler): sccz80
       passes 8/8 yet `make test_cpm_z80.com` still errors, because z88dk-ticks
       returns exit 1 for a `+cpm` warm-boot exit and the recipe's `|| exit 1`
       trusts it. (Other suites are green only via the `+test -b msx` `runtest`
       path, which halts cleanly.)
   (b) **llvmz80 open() = REGRESSION** from the md5sum `include/fcntl.h`
       `__LLVMZ80` fix over-reaching into +cpm (it was validated for +test STACK
       workers only). VERIFIED: gating the fcntl.h branch to
       `#if defined(__LLVMZ80) && !defined(__CPM)` keeps md5 (+test) GREEN and
       un-regresses +cpm open() (failure then moves :88 open -> :92 read).
       `__CPM` is defined under +cpm, not +test (confirmed via emitted-asm
       marker) = valid discriminator.
   (c) **write/read wrong count** = HL-vs-DE return-register + arg ABI of the
       sccz80-built cpm_clib = ALREADY FILED **ravn/z88dk#23** (umbrella #26).
       Do NOT file a dup. Deep (full register-ABI bridges), not header-only.
   REJECTED shortcut: switching cpm_z80 to `+test -b msx` host-fcntl does NOT run
   CP/M (it uses ticks host SYSCALLs, not BDOS) -> would be a false green.
   PLAN (awaiting go-ahead): Step1 harness output-parse gate (parse suite's
   "0 failed" summary instead of trusting ticks exit); Step2 gate fcntl.h to
   `!__CPM` (un-regress open, small); Step3 XFAIL residual +cpm disk tests under
   llvmz80 ref #23 (XFAIL framework already in test/framework/test.{c,h}).

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
