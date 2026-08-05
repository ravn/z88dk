# Why llvmz80 is ~5.4× faster than sdcc on `c90base_immul`

The per-component breakdown (`make components`, see README) shows llvmz80's
overall c90base speed lead over sdcc is concentrated almost entirely in one
sub-benchmark, `c90base_immul` (integer matrix multiply):

| component            | reps |     llvmz80 |       sdcc0 | llvmz80 faster |
| -------------------- | ---- | ----------: | ----------: | -------------: |
| c90base_immul        |    8 |  62,037,336 | 337,254,013 |         5.44×  |

Of the 395 M cycles llvmz80 saves over sdcc0 on the whole c90base workload,
`immul` alone accounts for **69.7 %** (275 M).  This note explains *why*, from
the generated assembly plus isolating micro-benchmarks — it is **not** primarily
"better register allocation / less memory traffic", though that contributes.

## What the benchmark does

`c90base_immul` (src/c90base-immul.c) runs, 200× in a loop:

```c
imul_mv(buf+4,  back, buf+0,  4);   /* vector × constant matrix */
imul_mv(buf+8,  left, buf+4,  4);
imul_mm(buf+12, left, back,   4);   /* constant matrix × constant matrix */
imul_mv(buf+4,  buf+12, buf+28, 4); /* vector × the product */
```

`back` and `left` are `static const int[16]` rotation matrices (entries are only
`0, ±1, ±2`).  `imul_mv`/`imul_mm` are `static` helpers taking `int *restrict`
and a **runtime** size `s` (always 4 here).  The multiply count per
`c90base_immul` call is fixed and identical for every compiler at the C level:
`imul_mv` = 16 mults, `imul_mm` = 64 mults.

## Root cause (from the emitted asm)

### 1. Dominant: llvmz80 inlines `imul_mm` and constant-folds it to nothing

`imul_mm(buf+12, left, back, 4)` multiplies two **compile-time-constant**
matrices.  In the llvmz80 asm:

- there is **no `_imul_mm` label** — clang inlined it into `c90base_immul`,
  propagated the constant `left`/`back`, and folded the whole 4×4×4 = 64-multiply
  product to compile-time constants.  The `c90base_immul` body issues
  **`call ___mulhi3` = 0 times**.
- sdcc keeps `_imul_mm` as a separate function called with runtime pointers, so
  it cannot see the arguments are constant and **re-executes all 64 multiplies
  on every one of the 200 iterations**.

Runtime 16-bit multiplies per `c90base_immul` call:

| function        | llvmz80        | sdcc  |
| --------------- | -------------- | ----- |
| imul_mv (×3)    | 48             | 48    |
| imul_mm (×1)    | **0** (folded) | 64    |
| **total**       | **9,600**      | 22,400 |

That is ~2.3× fewer multiplies for llvmz80 before any per-multiply cost is
considered.

### 2. Secondary (this is the register-handling part): llvmz80 unrolls `imul_mv`

For the multiplies both compilers *do* perform (`imul_mv`, which depends on the
`volatile` input vectors and so cannot be folded):

- llvmz80 **unrolls** the `s = 4` inner loops and keeps counters / pointers /
  accumulator in registers.
- sdcc keeps the loops **rolled**, with the loop counter in the IX stack frame
  (`inc (ix-2)`), real branches (`jp NZ`), and per-call argument marshalling for
  `__mulint_callee`.

So llvmz80's (fewer) multiplies also carry less surrounding overhead.

### 3. NOT the cause: the multiply routine itself

A micro-benchmark of 1000 volatile 16-bit multiplies (`+test`, z88dk-ticks):

| multiplier | llvmz80 `___mulhi3` | sdcc `__mulint` |
| ---------- | ------------------: | --------------: |
| b = 2      |             599,005 |         658,005 |
| b = 12345  |           1,039,005 |       1,079,005 |

The two routines are within 4–10 %, and **both** are operand-dependent (a small
multiplier is much cheaper — which is why `immul`'s `0/±1/±2` matrix entries make
its per-multiply average low for both compilers).  The routine is not the
differentiator.

## Takeaway

llvmz80's win here is chiefly **middle-end interprocedural optimization**
(inlining + constant propagation + constant folding removing an entire runtime
matrix multiply), with loop unrolling / register allocation as a secondary
contributor.  It is *not* the multiply routine and only partly "less memory
traffic".

**Caveat — partly a benchmark artefact:** `immul` multiplies compile-time-constant
matrices, which clang's stronger IPO exploits and sdcc does not.  In real code
with runtime matrices the constant-folding win (point 1) disappears and only the
unroll / register-allocation advantage (point 2) would remain, so the gap would
be considerably smaller.

Reproduce: `make components`; disassemble with
`LLVMZ80EXE clang --target=z80 -ffreestanding -O2 -S src/c90base-immul.c` and
compare `_imul_mm` (absent = inlined/folded) against the sdcc `-S` output.
