# LLVM-Z80 integration

The `llvmz80` compiler selects `z80-unknown-none-z88dk` and uses `__smallc` as
the default calling convention for plain C.  Variadic functions and main use
`sdcccall(0)` at code-generation time; that is handled by the backend without
any IR annotation.

Set `LLVMZ80EXE` to the clang executable.

## Calling conventions

In the z88dk environment, plain C is `__smallc` (arguments pushed left-to-right,
first argument furthest from SP).  Explicit `__sdcccall(0)` and `__sdcccall(1)`
attributes still annotate as usual.

The driver relies on the target ABI and does not inject a convention flag.
User `-Cg` options follow the default options.
The driver preprocesses in gnu23 mode.

## Library ABI note

The z88dk classic library (`cpm_clib`) is built with both sccz80 and SDCC
object files.  Because clang generates underscore-prefixed symbols (`_qsort`,
`_vsnprintf`, …), the SDCC variants of those functions are linked.  These
variants use `sdcccall(0)` for certain arguments:

- `vsnprintf` / `vfprintf`: called via `-fno-builtin-vsnprintf/vfprintf` so the
  `__attribute__((sdcccall(0)))` annotation in `stdio.h` is respected.
- `qsort` / `bsearch` comparator callbacks: `_qsort.asm`'s thunk calls the
  user comparator with `sdcccall(0)`.  Declare comparators with
  `__attribute__((sdcccall(0)))` to match.

Only the classic C library in z88dk is currently supported.  Newlib and other
C libraries are not supported.

## Running the tests

```sh
export PATH="$PWD/bin:$PATH"
export ZCC="$PWD/bin/zcc"
export ZCCCFG="$PWD/lib/config"
export LLVMZ80EXE=/path/to/clang
export NTVCM=/path/to/ntvcm  # or use z88dk-ticks
export TMPDIR=/path/to/workspace/scratch/tmp
make -C test llvmz80
```

The runtime tests check C23 at O0, O2 and Os.
They use independent expected values and repeat calls to check stack cleanup.
The tests require classic CP/M and an initialised heap.
They do not use `-fno-builtin`.

## Varargs / va_list

`va_list` uses LLVM's `__builtin_va_list`.  For `vsnprintf`, the `stdio.h`
header annotates it with `__attribute__((sdcccall(0)))` and the driver passes
`-fno-builtin-vsnprintf` to prevent clang's built-in knowledge from overriding
that annotation.

## C23 variadics

`va_start` without a parameter name is available in gnu23 mode.
