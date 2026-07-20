# Dhrystone 2.1 — three-way Z80 comparison

This directory benchmarks the same **Dhrystone 2.1** sources (`dhry_1.c`,
`dhry_2.c`, `dhry.h` — C/2.1, 25 May 1988, Reinhold P. Weicker) across three
z88dk-native Z80 lanes. The point is to separate *how much of a compiler's
Dhrystone score comes from the calling convention* from *how much comes from
the compiler proper* (middle-end + register allocator).

All three lanes compile byte-identical sources, link the same z88dk classic C
library (`+test`), and are timed with `z88dk-ticks` between the
`TIMER_START`/`TIMER_STOP` labels that `dhry.h` emits under `-DTIMER`. Every
lane is first correctness-checked with a `+cpm -DPRINTF` build whose 20
self-validation "should be:" values must all match (`make verify`).

## Lanes

- **`llvmz80/`** — ravn/llvm-z80 GlobalISel clang, `-O2`; z80 target with a
  16-bit register-passing ABI.
- **`sdcccall1/`** — `sdcc -SO3` forced to SDCC's version-1 calling
  convention (`--sdcccall 1`: args in registers, 16-bit return in DE). Needs a
  build-time PATH shim because zcc filters `--sdcccall`; safe against the
  version-0 library because z88dk headers pin each libc function's convention.
- **`z88dk-classic/`** — `sdcc -SO3` with z88dk's default version-0 convention
  (`--sdcccall 0`: stack frame via IX, callee cleanup).

## Results

Measured 2026-07-11, @ 4 MHz Z80, 20000 runs (regenerate with `./compare.sh`):

| Compiler / calling convention                        | cycles/run  | DMIPS   |
| ---------------------------------------------------- | ----------- | ------- |
| llvmz80 -O2 (z80 16-bit register ABI)                |        8461 |  0.2690 |
| sdcc --sdcccall 1 -SO3 (register convention)         |       11044 |  0.2061 |
| sdcc --sdcccall 0 -SO3 (z88dk default, stack)        |       12158 |  0.1872 |

`DMIPS = (runs / (cycles / freq)) / 1757` (1757 = VAX 11/780 dhrystones/s).

## What the numbers say

- Switching sdcc from its z88dk default (`--sdcccall 0`) to register-passing
  (`--sdcccall 1`) is worth **−9.2 % cycles / +10 % DMIPS** (12158 → 11044).
- llvmz80 at 8461 cycles/run is still **30.5 % faster than sdcc even with
  `--sdcccall 1`**. So the calling convention explains only about **a third**
  of the llvmz80 lead; the rest comes from LLVM's stronger middle-end
  (inlining `Func_1`, deleting Dhrystone's trivial one-trip loop) and register
  allocation. The static instruction count is essentially equal — the win is
  dynamic (cheaper hot-path instructions), not code size. See
  `llvmz80/readme.txt` for the annotated asm comparison.

## Regenerating

```sh
export PATH=/path/to/z88dk/bin:$PATH
export ZCCCFG=/path/to/z88dk/lib/config
./compare.sh            # builds all three lanes, prints the markdown table
FREQ=4000000 ./compare.sh   # override the assumed Z80 clock
```

Each lane can also be driven on its own: `cd <lane> && make benchmark` (timing)
or `make verify` (correctness under ntvcm).
