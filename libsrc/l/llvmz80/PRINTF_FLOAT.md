# Classic `printf("%f")` under llvmz80 (clang-z80)

Verified 2026-08-05 on Z80/ntvcm. Summarises why stock `printf("%f")` is a trap
on the llvmz80 lane and the two working routes. Companion to
[`CALLING_CONVENTION.md`](CALLING_CONVENTION.md) and the z88dk wiki page
[Classic -- Pragmas](https://github.com/z88dk/z88dk/wiki/Classic--Pragmas).

## The trap: `%f` silently prints a literal `f`

`zcc +cpm -compiler=llvmz80 ... printf("v=%f", 3.5)` prints `v=f` (the value is
dropped and the following varargs desync). This is **not** a clang miscompile —
it is how z88dk's *modular* classic `printf` selects converters:

- Each conversion (`%d`, `%s`, `%f`, ...) is a separately linked converter,
  chosen by the `CRT_printf_format` bitmask (`%f` = `0x04000000`).
- **sccz80** auto-scans the format-string literals at compile time and emits the
  mask automatically (`src/sccz80/callfunc.c` + `src/sccz80/main.c`).
- **zsdcc and llvmz80 do NOT** auto-scan (they are external/stock frontends), so
  they fall back to the library default table
  `libsrc/classic/stdio/__printf_format_table.asm`, which deliberately omits
  `f`/`e`. At runtime `asm_printf`'s `no_format_found` path prints the spec
  character literally and does not consume the vararg -> `v=f` + desync.

The wiki documents this for zsdcc ("if you use incremental builds or zsdcc then
you will need to configure the list of converters"); llvmz80 is in the same
category. See ravn/z88dk#25 (dhrystone) and #42 (auto-selection gap /
diagnostic).

## Route 1 (stock z88dk printf): `#pragma printf` + `--math32`

Force the converter set explicitly and link z88dk's 32-bit-IEEE float core:

```c
#include <stdio.h>
#pragma printf = "%6.1f %d %s"   /* list EVERY conversion used, width form incl. */
int main(void){ printf("v=%6.1f|d=%d\n", 3.5, 42); return 0; }
```
```sh
zcc +cpm -compiler=llvmz80 --math32 -O2 prog.c -o prog.com -create-app
# v=   3.5|d=42   (byte-identical to sccz80)
```

Two requirements, both verified necessary:

1. **`--math32`** supplies `asm_fpclassify` / `__dtoa_base10` / `__dtoa_digits`
   in **32-bit IEEE-754**, matching clang's `double`. Without it the `%f`
   converter fails to link (`undefined symbol: __dtoa_digits`). (The default
   genmath float is 48-bit math48 — wrong layout for clang.)
2. **The width form in the pragma** (`%6.1f`, not bare `%f`): the classic library
   distinguishes `%d` from `%0d`/formatted (wiki), so bare `%f` links only the
   unformatted path and `%6.1f` at the call site prints literally.

## Route 2 (nanoprintf closure): `__llvmz80_printf`

The `llvmz80-softfloat` project ships an IEEE-from-raw-bits nanoprintf shim
(`__llvmz80_printf`/`__llvmz80_snprintf`, `build_fmt.sh`) that needs **no**
float-math lib. Use it when you also need soft-float arithmetic, or want `%f`
without `--math32`. Note: `%e`/`%g` are a permanent nanoprintf design exception.

## Which to use

- Only need `%f` output (no double arithmetic): **Route 1** is simplest — one
  pragma + `--math32`, no extra archive.
- Already linking `softfloat_cpm_z80.lib` for double math, or want `%f` without
  `--math32`: **Route 2**.

Reconciling the two routes into a single recommended entry point is tracked in
ravn/z88dk#43. Newlib is out of scope (compat-only); see
`newlib/KNOWN_GAPS.md`.
