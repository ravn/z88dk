# Whetstone under llvmz80 (-O3): transcendental libm not ABI-bridged (2026-08-09)

Adding a Whetstone lane to the benchmark sweep (sibling of `dhrystone21/`)
surfaced a real integration gap. Whetstone is **double-precision floating
point** and, under llvmz80, `double` = IEEE-754 binary32 (float32-math32,
ravn/llvm-z80 #277). It exercises the soft-float closure far harder than the
integer benchmarks.

## What works

- **Builds and links at -O3** with the float bridges + math32:
  ```
  zcc +cpm -compiler=llvmz80 -O3 -DTIMER -mllvm -z80-float-sdcccall0 \
      -L<libsrc> -lmath32 \
      libsrc/l/llvmz80/{__addsf3,__cmpsf2,__floatsisf}.asm whetstone.c -m
  ```
  (The three `.asm` files are the #277-style bridges for f32 add/sub/mul/div,
  compares, and int↔f32 conversions — they must be passed explicitly, they are
  not in the default clib link set. TIMER_START/STOP land in the `.map`.)
- **f32 arithmetic + conversions are correct** (`0.75*10000 → 7500`, matches
  runtime_float.sh's ALL-PASS closure) and, with `--math32`, **sqrt** is correct
  (`sqrt(2)*1e4 → 14142`).

## What is broken — the gap

- **Transcendental libm returns garbage (0):** `exp`, `log` (and by extension
  `sin`, `cos`, `atan`) return 0 even though math32 ships them
  (`math32/lm32/c/sccz80/{log,exp,sin,cos,atan}.asm → _m32_*f`). Isolated repro:
  ```
  sqrt(2)*1e4 = 14142  (want 14142)   OK   [--math32]
  log(0.75)*1e4 = 0    (want -2877)   BAD
  exp(0.75)*1e4 = 0    (want 21170)   BAD
  0.75*10000 = 7500    (want 7500)    OK
  ```
- **Root cause:** `-mllvm -z80-float-sdcccall0` bridges only the `__*sf3`
  *arithmetic* libcalls to the sdcccall(0) ABI. A plain `double` C call like
  `exp(x)` is emitted with clang's default float-argument ABI, which does **not**
  match what math32's `_m32_expf`/`_m32_logf` expect for their argument — so the
  operand arrives wrong and the routine returns 0. `sqrt` happens to work via
  math32's separate asm fast path; the general libm entry points do not. This is
  the #277 problem one layer up: the **float-call ABI for libm functions is not
  bridged**, only the compiler-emitted soft-float arithmetic is.

## Consequence for the benchmark

The Whetstone **timing is therefore invalid** and must NOT be reported as a
score: the transcendental modules (a large share of Whetstone's work) compute 0
quickly, so any cycle count is meaninglessly low. Per the sweep discipline
(`llvm-z80/tasks/plan-2026-08-04-...`): *correctness-gate every lane before
trusting timing.* Whetstone fails that gate under llvmz80 today.

The gate itself was added to `whetstone.c` behind `-DSELFCHECK` (float-printf is
also unreliable on the classic/llvmz80 path, so it checks module-11's converged
`X ≈ 0.83467` via integer `%d`/`%s` only). It correctly reports **FAIL**
(`X*1e4=0`) right now — i.e. it does its job and caught the transcendental bug.

## RESOLUTION (2026-08-09) — header-only fastcall routing (no bridge)

Real root cause, found in `include/math/math_math32.h`: math32 already ships the
right mechanism — `#define exp(x) exp_fastcall(x)` (the `_fastcall` entries alias
the register-ABI `_m32_*f` cores) — but it is gated `#ifndef __STDC_ABI_ONLY`,
and **clang defines `__STDC_ABI_ONLY`** (`<sys/compiler.h>`, so classic-clib
`__smallc` functions like `putchar` work). So clang fell through to the *plain*
declarations, which resolve to the stack wrappers; clang passes the f32 arg in
registers, the wrapper reads the stack → garbage (0). (`sqrt`/`fabs` escaped
because their plain decls carry `__MATH32_ABI`; the transcendentals' plain decls
do not — the header comment intended that annotation but it was never applied to
them.)

**Fix (header-only):** the transcendental `_fastcall` routing blocks now also
fire for llvmz80 on the z80 target:

```c
#if !defined(__STDC_ABI_ONLY) || (defined(__LLVMZ80) && defined(__Z80__))
```

so clang gets `#define exp(x) exp_fastcall(x)` and calls `_m32_expf` directly via
`z80_fastcall` (clang emits the HL=hi/DE=lo ↔ HL=lo/DE=hi swap inline, on both
arg and return). The `&& __Z80__` scopes it to the z80 backend — **the llvmz80
clang targets both z80 and sm83, and this must not touch sm83** (math32 is z80
asm; sm83 keeps its original path). No bridge asm, no lib rebuild; sccz80/sdcc
unchanged (they never define `__STDC_ABI_ONLY`). Verified:

```
sqrt(2)*1e4 = 14142   log(0.75)*1e4 = -2876   exp(0.75)*1e4 = 21170   (all OK)
WHET-SELFCHECK: PASS (X*1e4=8346, want 8347+-7)   sccz80 unchanged
```

The Whetstone lane is now valid: `llvmz80/` builds at **-O3** and self-checks —
**271,231,890 cycles for 1e6 Whetstone instructions = 14.73 KWIPS @ 4 MHz**
(`make verify && make benchmark`). (The earlier "≈34 KWIPS" was the *invalid*
pre-fix number: the transcendental modules returned 0 quickly, inflating it.)

An earlier swap-glue bridge (`libsrc/l/llvmz80/__m32_libm_f32.asm`) also worked
but was superseded by this header fix (it measured within 0.1% — the whetstone
time is dominated by the math inside `_m32_*f`, not the call glue).

Regression guard: `z88dk/test/clang/runtime_libm.sh` (mirrors `runtime_float.sh`,
auto-discovered by `run_all.sh`) pins exp/log/sin/cos/atan under llvmz80.
Candidate ravn/z88dk issue in the #277 family (arithmetic #277, graphics-return
#50) — the transcendental libm routing gate was the missing member.
