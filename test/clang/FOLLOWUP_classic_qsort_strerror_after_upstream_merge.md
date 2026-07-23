# Follow-up: 2 classic clang regressions from the 2026-07-23 upstream merge

Merging `upstream/master` (commit `b6ce4aedc6`) into ravn/master brought in new
library implementations that two ravn llvmz80 classic bridges were built against.
On the **classic** clib path (`-clib=default`, `-compiler=llvmz80`) two tests
now fail; **newlib is unaffected** (newlib_iy all green, 22 PASS). Not in the
production firmware path (rcbios/autoload/CP-NET/cpnos don't use qsort/strerror).

Nothing here blocks the signed-mod fix, which is done (see
`BUG_newlib_signed_mod.md`).

**Tracking issues:** qsort → ravn/z88dk **#33**; strerror → ravn/z88dk **#32**
(pre-existing; commented with the post-merge manifestation).

## 1. runtime_qsort — comparator ABI mismatch with upstream's redesigned qsort  (#33)

Upstream replaced the classic qsort machinery (`qsort_sccz80`/`qsort_sdcc`/
`qsort_sdcc_callee`, all deleted) with a single sort core plus **per-compiler
comparator thunks**: each compiler links a distinct entry (`qsort` for sccz80,
`_qsort` for sdcc) that builds a closure on the stack passing the comparator
address in `ix`; the shared core does `call l_jpix`, landing on the thunk
(`l_cmp_sccz80` / `l_cmp_sdcc`) which marshals the two operands in the
compiler's argument order. See `libsrc/classic/stdlib/qsort.asm`,
`_qsort.asm`, `qsort_core.asm`.

ravn's old integration (an `stdlib.h` `__qsort_llvmz80` inline that reversed the
args and called the now-deleted `qsort_sdcc_callee`, plus a `__smallc`
comparator requirement) was dropped in the merge (took upstream's `stdlib.h`).
Now `_qsort` links (from `z80_crt0.lib`) but the comparator is invoked with the
wrong convention → the program runs but produces no/garbage output.

**To fix:** decide how clang-z80 should reach upstream's new qsort. Either
(a) confirm clang's default `sdcccall(1)` comparator matches `l_cmp_sdcc`'s
marshalling and add the right `stdlib.h` routing for `__LLVMZ80` (clang emits
`_qsort`), or (b) add a clang comparator thunk (`l_cmp_clang`/`l_cmp_llvmz80`)
if the marshalling differs. Then restore/update the `__smallc`-comparator
contract in `runtime_qsort.c` to whatever the new design needs.

## 2. runtime_strerror — `__rodata_error_strings_head` not pulled  (#32)

Upstream's `libsrc/string/z80/asm_strerror.asm` references
`__rodata_error_strings_head`. ravn's `libsrc/l/llvmz80/__strerror_table.asm`
DEFINES that symbol (it is present in `z80_crt0.lib` — 11 bridge/qsort symbols
confirmed), but the link fails `undefined symbol: __rodata_error_strings_head`:
the defining module is not pulled on-demand across the `cpm_clib.lib` →
`z80_crt0.lib` boundary in the current link order.

**To fix:** ensure `__strerror_table` is pulled — e.g. give upstream's
`asm_strerror` a reference the linker resolves from the crt lib, move
`__strerror_table.asm` into `cpm_clib`'s module set, or add an explicit
`EXTERN`/anchor. Verify against upstream's intended strerror string-table
mechanism (upstream may now ship its own table that ravn's bridge should defer
to).

## Rebuild notes captured this session (for whoever picks this up)

- The lib toolchain is **native** (no Docker): `z88dk-sccz80`, `z88dk-zsdcc`,
  `z80asm` in `bin/`. The old CLAUDE.md "z88dk via Docker" note was stale.
- `make -C libsrc TARGETS=cpm` builds `cpm_clib.lib`; `TARGETS=z80` builds
  `z80_crt0.lib` (which holds the l/llvmz80 bridges + qsort); `make -C libsrc
  install` copies `libsrc/*.lib` → `lib/clibs/`. newlib: `make -C libsrc/newlib
  cpm`. z80asm `-d` reuses stale `.o`, so `*-clean` (or `make -C libsrc clean`)
  before a source-changing rebuild.
- Fixed en route: ravn's `libsrc/stdlib/c/sccz80/strtol.asm` used `IX` under a
  bare `IF __CLASSIC`, breaking the 8080/8085/gbz80 classic builds; now guarded
  `IF !__CPU_INTEL__ && !__CPU_GBZ80__` (clang only targets Z80).
