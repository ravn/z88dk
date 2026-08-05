<!-- DRAFT for discussion with the z88dk maintainers. Not posted anywhere.
     Authored by Copilot (AI) on @ravn's behalf; the design decision is
     explicitly deferred to the z88dk maintainers (user directive 2026-08-05:
     "dette er en ting der skal tages op med z88dk maintainerne, om hvad den
     rigtige løsning er"). -->

# Design question: how should `-compiler=llvmz80` handle 64-bit (`.quad`) global initializers?

## RESOLUTION (2026-08-05, implemented) — split in the backend, no external pass

User directive: "jeg vil helst gå efter Data64bitsDirective". Chosen and
implemented. This is a *fourth* option, cleaner than the three debated below:
neither an external perl pass nor a z80asm change nor a regression.

`ravn/llvm-z80` `Z80MCAsmInfo` (the ELF/GNU textual path clang `--target=z80 -S`
uses) now leaves **`Data64bitsDirective = nullptr`**. With that field null,
`MCAsmStreamer::emitValueImpl` already splits every 8-byte value into two
little-endian 4-byte `.long` emissions — so clang emits, e.g.,
`0x4008000000000000` as `.long 0` / `.long 1074266112` and **no `.quad` ever
reaches the bridge**. copt's existing correct `.long -> DEFQ` (4-byte) rule then
lowers each half faithfully.

Why it is safe on this target: a *symbolic/relocatable* 8-byte value would hit
`emitValueImpl`'s `report_fatal_error` non-absolute path, but one cannot be
formed here — casting a 16-bit address to a 64-bit initializer is rejected by
the front-end as non-constant, and all `.quad` values clang emits are absolute
integer constants. The change affects only textual `-S` output; the
integrated-assembler ELF object path never consults this field.

Consequences (done):
- `lib/llvmz80/splitquad.pl` **deleted**; removed from `bridge_postproc.sh`.
- `ravn/llvm-z80` lit test `llvm/test/CodeGen/Z80/quad-init-split-27.ll` pins the
  two-`.long` emission (`.quad` forbidden via `CHECK-NOT`).
- End-to-end `test/clang/runtime_quadinit.{c,sh}` passes under ntvcm with the
  external pass gone (backend split alone; red/green verified).
- No regression: 64-bit global initializers stay correct. Requires a clang built
  with this MCAsmInfo change (they are developed and shipped together in this
  fork).

The maintainer-facing analysis below is retained for the record.

---

## (historical) The problem (verified)


Under `zcc +cpm -compiler=llvmz80`, `clang --target=z80 -S` emits a 64-bit
global initializer as a GNU 8-byte `.quad <value>`. z88dk's assembler has **no
8-byte data directive** — `DEFQ` is 4 bytes (proof: `DEFQ 0x11223344` + `DEFB
0xAA` assembles to 5 bytes). So the value cannot be lowered by a plain text
substitution. The original copt rule `.quad %1 -> DEFQ %1 / DEFQ 0` truncated
the value to its low 32 bits and overwrote the true high 32 with the padding
`DEFQ 0` (ravn/z88dk#27). Affects any `long long` / `unsigned long long` global
initializer with bits above bit 31. (`double` does **not** reach this path here:
clang-z80 lowers `double` to a 4-byte `.long`/float, and z88dk uses the
math32/math48 float runtime.)

## Why copt cannot fix it on its own (verified 2026-08-05)

copt is more than pure text substitution — it has an output-side `%eval(<rpn>)`
arithmetic emitter (operators `>>`,`<<`,`&`,`|`,`+ - * /`, `%n` variables). But
the whole evaluator is hardwired to C `int` (32-bit): `int stack[]`,
`push(int)`/`pop()->int`, `int n = strtol(...)`, result emitted via
`sprintf("%d")` (`src/copt/copt.c` ~868–990). Built copt and reproduced:

- `.quad 4613937818241073152` (0x4008000000000000) with rule
  `.long %eval(%1 4294967295 &) / .long %eval(%1 32 >)` emits `.long 0 / .long 0`
  — the 64-bit literal is truncated to `int` **at parse time**, so the high 32
  bits are gone before any operator runs.
- `.quad 7` emits `.long 7 / .long 7` — `7 >> 32` on a 32-bit `int` is UB (shift
  count masked mod 32 → `>>0`).

So splitting a `.quad` needs 64-bit arithmetic copt does not have.

## Current solution in the fork (works, but the point of debate)

`lib/llvmz80/splitquad.pl` — a pre-copt pass (Math::BigInt, exact 64-bit) that
splits every `.quad <v>` into two little-endian `.long` halves, which copt's
correct `.long -> DEFQ` (4-byte) rule then lowers faithfully. Handles decimal,
negative (two's complement), `0x`hex, and symbolic operands (zero-extended,
Z80 addresses being 16-bit). Committed as a96bebcc61; a red/green regression
test lives at `test/clang/runtime_quadinit.{c,sh}`. It is one of **three**
external perl pre-passes already in the same bridge (`bridge_postproc.sh`):
`splitquad.pl`, `splitascii.pl` (copt's 512-char MAXLINE), and `fixlabels.pl`
(dots in labels copt tokenises on whitespace).

## @ravn's preferred direction (to validate with maintainers)

Rather than carry an external program for this, treat **initializing a 64-bit
variable with a value** as a *known, documented limitation* of the
`-compiler=llvmz80` path that emits a **warning from clang**, and drop
`splitquad.pl`.

Tradeoff to be explicit about: this **regresses currently-correct behavior** —
64-bit global initializers that work today would then be unsupported/warned.

## Open questions for the maintainers

1. **External pre-pass policy.** Is a perl pre-pass in the bridge acceptable
   (as `splitascii.pl` / `fixlabels.pl` already are), or should the project
   avoid adding new ones? If the latter, does the same reasoning imply retiring
   the two existing ones?
2. **Warning origin.** If we go the "documented limitation + warning" route,
   should the warning be a genuine clang diagnostic in `ravn/llvm-z80`
   (target-specific, fired when an 8-byte initializer with data is lowered), or
   a bridge-level warning printed during the `zcc` build? "A warning from clang"
   was the stated wish, which points at the former (an llvm-z80 change).
3. **Proper fix instead?** Should z88dk's z80asm gain real 8-byte data support
   (extend `DEFQ`, or add a new directive), making the whole split unnecessary
   and lowering `.quad` directly? This is the only option that keeps 64-bit
   initializers working without an external pass.
4. **Degraded behavior.** If unsupported, what should the bridge do with a
   `.quad` — hard error at build time, or warn + emit a defined-but-truncated
   value? (A silent truncation is what #27 was; that should not return.)

## Recommendation

Keep `splitquad.pl` as the working baseline until the maintainers decide, so no
regression is introduced meanwhile. If the project wants the limitation route,
prefer a hard **error** (not a silent truncation) plus documentation, so the
failure mode is loud. The cleanest long-term answer is (3) native 8-byte data
in z80asm.
