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

## STATUS — full suite GREEN under llvmz80 (target_io Steps 1-3 done; regex #39 FIXED; math #278 xfail)

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

## RESOLVED — full suite GREEN under llvmz80 (segment 2, 2026-08-03)

**`make -C test/suites COMPILER=llvmz80 all` now exits 0** — 77 suite summaries,
all `0 failed`, 0 errors/XPASS. Two suites carry documented xfails: target_io
(5 xfail, ref #23) and math (2 xfail, ref #278). Segment-2 commits (this file's
branch, local only):

1. **regex — FIXED (`include/regexp.h`, `__LLVMZ80`-gated).** The #39 filing's
   symptom was right ("corrupted program") but its ROOT CAUSE was only partly
   right. Two independent ABI bugs, both fixed:
   - **regcomp/regerror** were declared with NO calling convention, so clang
     used its default sdcccall(1): it passed the pattern in **HL** and read the
     returned `regexp*` from **DE**, while the sccz80 worker wants the arg on
     the **stack** and returns in **HL**. So `regcomp()` returned a GARBAGE
     pointer — the corruption originated HERE, before regexec ran. Fix: declare
     both `__smallc` (1-arg -> stack arg + HL return, order moot).
   - **regexec/regsub** need a **reversed-arg __smallc forwarder**, NOT a
     straight decl. Verified from the compiled `___regexec` prologue: the sccz80
     `__smallc` worker reads `prog` at `[sp+8]` = the DEEPEST arg slot (first arg
     deepest), but clang `__smallc == sdcccall(0)` pushes first-arg-SHALLOWEST
     (cdecl) — the two conventions are **MIRRORED for multi-arg calls**. So the
     forwarder reverses the params (`__regexec(string,prog)` fwd from
     `regexec(prog,string)`) to land prog in the deep slot.
   DURABLE LESSON: clang `sdcccall(0)`/`__smallc` and sccz80 `__smallc` share the
   HL return + stack passing but have **OPPOSITE multi-arg push order**; any
   multi-arg sccz80 `__smallc` worker called from clang needs reversed args
   (same as the fcntl.h workers). 1-arg workers only need the `__smallc` tag.
   Verified: regex 14/14 patterns pass; sccz80 + sdcc still 1/1.

2. **target_io — GREEN (Steps 1-3 of the plan, all done).**
   - Step 1 (harness, `test/suites/target_io/Makefile`): new `run_check` define
     parses the framework summary and passes iff `run>0 && failed==0 &&
     passed+xfail==run` instead of trusting z88dk-ticks' warm-boot exit code.
     The `passed+xfail==run` term is essential — it catches sdcc, which
     warm-boots mid-suite after test 4 and emits a stale `8 run, 4 passed,
     0 failed` (4!=8 -> correctly RED, not a false green). Also gated `all` to
     the native +cpm z80 recipe under llvmz80 (the 8085/rc2014/newlib recipes
     pin clibs/targets the z80-only clang backend can't build). sccz80 8/8 GREEN.
   - Step 2 (`include/fcntl.h`): gated both `#if defined(__LLVMZ80)` open/read/
     write guards to `&& !defined(__CPM)`. md5 (+test) stays GREEN; +cpm open()
     un-regressed (failure moved :88 -> :92).
   - Step 3 (`io_tests.c`): the 5 +cpm disk tests are XFAIL under
     `defined(__LLVMZ80) && defined(__CPM) && !TIO_USE_HOST_FCNTL`, ref #23.
     Precisely gated so sccz80/8085/host paths keep asserting all 8.
     Result: llvmz80 `8 run, 3 passed, 0 failed, 5 xfail`, exit 0.

3. **math — GREEN via `all`-gate (`test/suites/math/Makefile`).** The suite was
   only ever green when `test_math32.bin` was built DIRECTLY; `make all` still
   listed every format (genmath/mbf32/math48/...) and failed first on
   test_genmath (undefined `___subsf3`/`___cmpsf2`/`_fabs` — 48-bit lib lacks the
   binary32 libcalls). The Makefile's own comment already said llvmz80 should
   "build ONLY the Math32 primary", but `all` wasn't gated. Fixed by gating
   `ALL_TARGETS` to `test_math32.bin` under llvmz80 (mirrors far/zx opt-out).
   Result: `16 run, 14 passed, 0 failed, 2 xfail` (pow/fmod xfail, #278), exit 0.

## Suites verified GREEN under llvmz80 (all)

string ctype stdio stdlib(classic) md5 target_io math regex + all benchmark
suites (charbench crcbench intbench ptrbench sieve rle sortbench queenbench
searchbench switchbench structbench vecbench maskbench strbench listbench
interpbench matrixbench hashbench fixedbench histbench lexbench) + sccz80.
Excluded by design (per-compiler opt-out): far, recordbench(#38), zx,
stdlib-newlib.

## Constraints (standing)
- No push/PR/history-rewrite unless asked. Do not "fix" UB/ABI-specific tests by
  rewriting their logic (recordbench precedent, #38) — exclude or #ifdef.
- Every float/ABI bridge MUST be runtime-verified under ntvcm.
- Durable notes live in-project (this file), never ~/.claude/.
