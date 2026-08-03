# z88dk × llvmz80 — resume note 2026-08-03 (branch `llvmz80-float32-math32`)

Continuation of the classic-clib llvmz80 integration. This branch's segment
covered the z88dk **test-suite** under `-compiler=llvmz80` and a zcc driver fix
for the IEEE-float32 (math32) path. Nothing pushed (standing rule: no push/PR
unless asked). `upstream-issue-draft.md` is unrelated leftover — leave alone.

## Environment (set for every build/run)

    export PATH=/Users/ravn/z80/z88dk/bin:$PATH
    export ZCCCFG=/Users/ravn/z80/z88dk/lib/config
    export LLVMZ80EXE=/Users/ravn/z80/llvm-z80/build-macos/bin/clang

## DONE this segment (commits, newest first)

- `ef85518d3e` **zcc: consume sccz80 `-fp-mode` for `-compiler=llvmz80`.**
  `-fp-mode=<x>` is an sccz80/sdcc double-format selector, not a zcc option;
  zcc was forwarding it to clang -> `unknown argument: '-fp-mode=ieee'`. New
  helper `strip_flag_prefix()` in `src/zcc/zcc.c` drops `-fp-mode*` from
  `comparg` in the CC_LLVMZ80 branch of `configure_compiler()` (clang-z80 is
  IEEE-only, so it's a no-op). Verified RED->GREEN: byte-identical output
  with/without the flag; sccz80 still honours it; zcc rebuilt+installed
  (`make -C src/zcc PREFIX=/Users/ravn/z80/z88dk install`). Full writeup:
  `libsrc/l/llvmz80/MATH32_BRIDGE.md` §7.
- `17d5aba1fe` **test/suites: build only the z80 primary under llvmz80.**
  `test/suites/make.config` overrides all non-z80 CPU compile/runtest macros
  to a skip echo when `COMPILER=llvmz80` (z80-only backend; no Rabbit/8080/…).
- `339c7cacfa` **test/suites: XFAIL recordbench for llvmz80.** `recordbench.c`
  has signed-overflow UB (`p->a+p->b` reaches 65288 > INT16_MAX before the
  `& 0x7fff`); exposed only under 16-bit int **and** a UB-exploiting optimizer.
  Test left untouched; filed **ravn/z88dk#38**. Extended the existing
  per-compiler `filter-out` in `test/suites/Makefile`.
- `697a0d4620` / `ca557d536c` — the rejected int->unsigned recordbench change
  and its revert (kept for history; test stays pristine).
- `e8612ac2e4` — md5sum `+test` fd-layer ABI fix (open/read/write) in
  `include/fcntl.h` (prior segment).

## OPEN — `test/suites/math` `test_math32.bin` link gap (NOT a compiler bug)

After the `-fp-mode` fix the target compiles, then fails at **link** with
undefined `sf` compiler-rt symbols (`___addsf3`, `___mulsf3`, `___cmpsf2`, …).
Cause: the stock target links only z88dk's `-lmath32` (entry points `cm32_*`),
which does not define the compiler-rt names clang emits for `float`. It wires
up neither float32 runtime path. See `MATH32_BRIDGE.md` §7b. To make it
link+run under llvmz80 (a **test-harness** change, tracked separately):
- Path B (light, preferred): add `-mllvm -z80-float-sdcccall0` + the bridge
  aliases in `libsrc/l/llvmz80/` (`__addsf3.asm`/`__cmpsf2.asm`/`__floatsisf.asm`)
  on top of `-lmath32`. Correctness already proven by
  `test/clang/runtime_float|fcmp|fconv.sh`.
- Path A (heavy): link the `llvmz80-softfloat` archive. NB: at time of writing
  that archive did **not** rebuild cleanly (its f64 closure driver pulled
  unresolved f32 wrappers) — an independent issue in that repo.

## Also OPEN (pre-existing, out of scope, revealed by z80-primary scoping)

~35 z80-primary llvmz80 failures across bespoke suites: stdio/test_scanf
(implicit `strcmp` — missing `#include <string.h>`), math (all libs), regex,
sccz80 suite, zx (~12), stdlib/test_newlib, target_io. Each is its own case.

## Constraints (standing)
- No push/PR or history rewrite unless explicitly asked. All above commits are
  local only.
- Do not modify `recordbench.c` (UB is in the test; XFAIL'd, #38 filed).
- Every new float/ABI bridge MUST be runtime-verified under ntvcm.
- `store_memory` is unavailable for this repo → durable notes live in-project.
