<!-- DRAFT, not posted. Prepared for z88dk/z88dk discussion per
ravn/llvm-z80 #277 (llvmz80 float32/math32 bridge investigation).
NOT to be filed without explicit go-ahead (project rule
feedback_explain_before_filing). -->

# Discussion: is math32's `float` division slower than it needs to be?

**From @ravn (human):**

It was found during adaptation of llvmz80 to math32, that the math32
"div" routine for 32-bit floats was only half the speed of the implementation provided with the
compiler itself. 

Apparently this is because math32 calculates
1/x first using Newton-Raphson, which is slower on the z80 than just doing the division directly.   Note that the result is correct, but the algorithm is slower than it could be.  

License of llvmz80 code is permissive, so it is possible to adapt this implementation to math32 if desired.  


AI blurb below provide more detail.

---

**From Copilot (AI):**

## Summary

Comparing `m32_fsdiv` (math32's float division) against LLVM compiler-rt's
`__divsf3` for z80 showed compiler-rt's routine is markedly faster
(measured ~2.3x on a raw T-state comparison, see below). The two use
different algorithms: math32 computes `a/b` as `a * (1/b)`, finding the
reciprocal via Newton-Raphson iteration; compiler-rt does direct 24-bit
restoring binary long division on the mantissas, no reciprocal, no
multiply. This issue is a **discussion**, not a bug report or a patch:
NR is a legitimate, correct design choice that simply loses to direct
long division on the Z80 specifically, because the Z80 has no hardware
multiplier -- each NR iteration's cost (several float multiplies) is
disproportionate to what a fixed 24-step compare/subtract/shift loop
costs on this ISA.

## Why: algorithm, not a bug

**math32** (`libsrc/math/float/math32/asm/z80/f32_fsdiv.asm`,
`m32_fsinv_fastcall`) computes the reciprocal `1/b` via a degree-2
polynomial seed (`X0 = 140/33 + (-64/11 + 256/99*D')*D'`) followed by two
refinement steps `X := X + X*(1 - D'*X)`. Counting the seed, that's
roughly 8 full float multiplies + 7 float adds worth of sub-calls
(`m32_fsmul24x32`/`m32_fsmul32x32`/`m32_fsadd24x32`/`m32_fsadd32x32`),
plus a final multiply by the dividend to get the quotient. NR halves the
number of *iterations* needed for a given precision, which is the right
trade-off when multiplication is cheap (e.g. hardware FPU/multiplier) --
but on Z80, `m32_fsmul` is itself a multi-byte shift-and-add routine, not
a single instruction, so "fewer iterations, each an expensive multiply"
does not win here.

compiler-rt's z80 `__divsf3` (`compiler-rt/lib/builtins/z80/divsf3.asm`,
LLVM project, permissively licensed -- see licensing note below) instead
unpacks the 24-bit mantissas and runs a fixed 24-iteration
compare-subtract-shift loop (`djnz`-driven) -- no multiply at all. More
iterations, but each one is cheap.

This is also the reason for a known 1-ULP rounding difference between the
two approaches (e.g. on `-3/3`): NR's accumulated rounding differs
slightly from a direct divider's exact guard/round/sticky-bit tracking.
Neither is "wrong"; they're different valid roundings arrived at via
different paths.

## Reproducible benchmark (attached)

To let this be checked independently rather than taken on faith, **three**
builds are attached (two rebuildable by anyone with just z88dk, one
pre-built since it needs an llvm-z80 toolchain most z88dk maintainers
won't have):

- `divtest.c` -- shared test source for the first two builds (N=2000-call
  loop, fixed operands `3.14159f / 2.71828f` every iteration), selected
  via a compile-time `-DUSE_MATH32` switch so the two builds differ only
  in which division routine is exercised.
- `directdiv.h` -- a portable-C reference implementation of the "direct
  restoring division" family (unpack sign/exponent/24-bit mantissa,
  24-iteration compare-subtract-shift loop, round, repack) -- structurally
  the same approach as compiler-rt's `__divsf3`, but written as plain
  portable C rather than hand-tuned Z80 assembly, precisely so it can be
  built and inspected with nothing but a stock z88dk/SDCC toolchain (no
  llvm-z80/clang involved).
- `compilerrt_div_test.c` -- a freestanding test harness (same operands,
  same N=2000 loop) linked directly against LLVM compiler-rt's real z80
  `__divsf3` assembly implementation -- the actual hand-tuned routine,
  not the portable-C reference above. Build commands are in the file's
  header comment; **also attached pre-built** (`compilerrt_div_test.bin`
  + `.elf`, produced on my machine from this exact source) so it can be
  run/inspected without needing an llvm-z80 build at all.
- `build_and_measure.sh` -- reproduces the first two builds from a clean
  checkout unconditionally, and the third if `LLVM_Z80_BUILD` happens to
  be set:
  ```sh
  PATH=<z88dk>/bin:$PATH ZCCCFG=<z88dk>/lib/config ./build_and_measure.sh
  ```

### Results (N=2000 divisions, z88dk-ticks, reproducible via the script above)

| build | implementation | total T-states | T-states/call |
|---|---|---|---|
| `math32_div_test` | math32 `m32_fsdiv` (Newton-Raphson reciprocal) | 48,980,572 | 24,490.3 |
| `directdiv_test` | direct restoring division, portable C reference | 33,642,572 | 16,821.3 |
| `compilerrt_div_test` | compiler-rt `__divsf3`, real hand-tuned Z80 asm | 21,594,032 | 10,797.0 |

- The **naive C reference** of the same algorithm is already ~1.46x
  faster than math32 -- a conservative lower bound, since it has none of
  the register-allocation tuning a hand-written routine would.
- The **real compiler-rt implementation** (same algorithm family, hand
  optimized) is ~2.27x faster than math32 -- consistent with the
  independent measurement in the llvmz80 bridge work
  (`z88dk/libsrc/l/llvmz80/MATH32_BRIDGE.md` Sec. 5, itself reproducible
  via `z88dk/test/clang/bench_math32_vs_compilerrt.sh`).
- The gap between the naive-C row and the real-asm row (16,821 vs.
  10,797) is the realistic remaining headroom a hand-tuned z80 asm
  implementation of the same algorithm could still capture beyond what
  this portable-C reference demonstrates.

Confirmed deterministic: rerunning `build_and_measure.sh` (both with and
without `LLVM_Z80_BUILD` set) reproduced identical T-state totals across
repeated runs on the same machine.

## What this issue is (and isn't) asking

This is a **discussion starter**, not a proposed patch: is it worth
z88dk considering a direct-division implementation for `m32_fsdiv` on
z80/z180/z80n (either replacing the current NR approach, or offering it
as a build-time alternative)? The trade-off is real -- NR is correct and
reasonable in the abstract, and there may be reasons (code size, other
targets sharing this routine, historical compatibility) to keep it as-is
-- but the timing gap seemed large enough, and easy enough to demonstrate
reproducibly, to be worth raising.

## Licensing note

compiler-rt's z80 `divsf3.asm` (the routine linked into
`compilerrt_div_test.bin`) is triple-licensed `Zlib OR Apache-2.0 WITH
LLVM-exception OR MIT` (see the SPDX header in the file) -- all three are
permissive with no copyleft/share-alike obligation, so if z88dk
maintainers want to look at or adapt that algorithm/implementation
directly, that's available under any of those three licenses (attribution
notice would need to be retained, per each license's terms). The source
itself is not attached here since the discussion is about the algorithm
choice, not a proposed direct code lift, but it can be provided on
request, and the compiled binary linked against it (`compilerrt_div_test.bin`/`.elf`)
is attached for the timing comparison.

## Attached files

- `divtest.c`, `directdiv.h` -- math32 vs. direct-division reference,
  rebuildable with z88dk alone.
- `compilerrt_div_test.c` -- pure compiler-rt harness source (needs
  llvm-z80 to rebuild).
- `compilerrt_div_test.bin`, `compilerrt_div_test.elf` -- pre-built from
  the above on my machine, so the compiler-rt comparison can be run/
  inspected without an llvm-z80 toolchain.
- `build_and_measure.sh` -- reproduces all of the above (first two
  unconditionally, the third if `LLVM_Z80_BUILD` is set).
