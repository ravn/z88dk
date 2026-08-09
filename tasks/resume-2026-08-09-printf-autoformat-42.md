# z88dk × llvmz80 — printf/scanf converter auto-selection (ravn/z88dk#42), 2026-08-09

Branch `fix/llvmz80-graphics-hl-return`. All commits **local only** (no push/PR).

## Problem (ravn/z88dk#42)

Stock classic `printf("%f")` under the external/stock frontends (llvmz80,
zsdcc) **silently printed a literal `f`** and desynced the following varargs:
z88dk's classic printf links each conversion as a separate converter chosen by
the `CRT_printf_format` bitmask, and only **sccz80** auto-scans the format
literals at compile time to emit that mask. zsdcc/llvmz80 fell back to the
default table (which omits `f`/`e`), so `%f` hit `asm_printf`'s
`no_format_found` path.

## Fix — auto-select in `zpragma`, not the clang frontend

The clang frontend is the wrong layer: it is invoked `-ffreestanding`, emits no
consumable converter mask, and baking z88dk's classic linker ABI into the
compiler is un-upstreamable + fixes only one lane. `zpragma` already owns the
converter tables, runs on every external-frontend TU (`.i2`->`.i`), and is
frontend-agnostic — so the compile-time scan sccz80 does internally belongs
there.

New `-autoformat` mode in `src/zpragma/zpragma.c` replicates sccz80:
- `format_arg_index()` — mirrors `SetWatch` (which call arg is the format).
- `scan_format_literal()` — mirrors `SetMiniFunc`; scans a real format literal
  (respects literal boundaries + C adjacent-string concat), OR-ing converter
  bits; sets `0x40000000` (flags handling) on any flag/width/precision so
  `%6.1f` renders instead of printing `6.1f`.
- `scan_line_for_formats()` / `emit_auto_format()` — find call sites, emit
  `CRT_printf_format`/`CRT_scanf_format` into `zcc_opt.def` with sccz80's exact
  OR-combining idiom (accumulates across TUs; explicit `#pragma printf` still
  wins).

`src/zcc/zcc.c` appends `-autoformat` to the zpragma call for
`CC_LLVMZ80 || CC_SDCC`. sccz80 auto-scans internally (outside this block);
ez80clang excluded (untested clib -> #60).

## Commits (newest first)

- `403106173c` **docs: note zsdcc lane also auto-selects** (PRINTF_FLOAT.md,
  CALLING_CONVENTION.md).
- `0b83f28b8c` **extend -autoformat to zsdcc** (gate `CC_LLVMZ80 || CC_SDCC`) +
  `test/clang/runtime_printf_autoformat_zsdcc.sh`.
- `9025d386de` **docs: printf %f converters now auto-selected — pragma optional**
  (PRINTF_FLOAT.md, CALLING_CONVENTION.md, CAPABILITIES.md).
- `1db8f84999` **zpragma auto-select for llvmz80** (core scanner + `-autoformat`
  flag + `test/clang/runtime_printf_autoformat.{c,sh}`).

## Verification

Stock `printf("v=%6.1f|d=%d|s=%s")` + `--math32`, **no** `#pragma`:
- `-compiler=llvmz80` -> `v=   3.5|d=42|s=ok`
- `-compiler=sdcc`    -> `v=   3.5|d=42|s=ok`  (byte-identical to sccz80)

Full clang integration suite: **55 PASS / 0 FAIL / 3 SKIP / 1 XFAIL**.

`%f` still requires `--math32` on **both** external lanes — the explicit pragma
fails identically without it (`asm_fpclassify` undefined). Pre-existing, not
introduced by the auto-scan; and that undefined-symbol link error is now the
actionable failure mode (was silent `f`), covering #42's ask #2 for the
missing-math case.

## Issues filed this session

- **#58** — scanf `%f`/`%e`/`%g` pulls sccz80's 48-bit floatpack
  (`init_floatpack`/f48) instead of math32; fails to link even with explicit
  `#pragma scanf` (pre-existing; auto-scan merely surfaces it).
- **#59** — no diagnostic when a printf/scanf format is a **non-literal**
  (runtime) string; a mixed TU can silently under-select a converter. Asks for
  a `zpragma` note. Also folds in the split-literal (`"%" "f"`) limitation.
- **#60** — consider wiring `-autoformat` for the **ez80clang** lane once its
  classic clib converter mechanism is verified.

## Env

    export PATH=/Users/ravn/z80/z88dk/bin:$PATH
    export ZCCCFG=/Users/ravn/z80/z88dk/lib/config/
    export LLVMZ80EXE=/Users/ravn/z80/llvm-z80/build-macos/bin/clang
    export NTVCM=/Users/ravn/z80/ntvcm/ntvcm
    # rebuild after zpragma/zcc edits:
    make -C src/zpragma PREFIX="$PWD" install
    make -C src/zcc     PREFIX="$PWD" install
