# ravn/llvm-z80 clang crash: aggressive-instcombine segfault at -O2/-Os

**Status:** open, unfiled (needs go-ahead before filing at ravn/llvm-z80).
**Discovered:** 2026-08-04, porting stdcbench 0.8 to the z88dk `+cpm -compiler=llvmz80` lane.

## Symptom (verified)

The ravn/llvm-z80 clang backend **segfaults (signal 11)** when compiling the
stdcbench `c90lib` module file `c90lib-lnlc.c` at `-O2` or `-Os`.  `-O0` and
`-O1` compile cleanly.  Every other compiler z88dk drives (sdcc `--sdcccall 0`,
sccz80) compiles the same file without error, so this is **llvmz80-specific**.

Crash location, from the pass-manager stack dump:

```
5.  Running pass "aggressive-instcombine" on function "add"
clang: error: clang frontend command failed due to signal
```

`aggressive-instcombine` is a generic middle-end LLVM pass; the crash surfaces
under `--target=z80`, so it is either a generic AggressiveInstCombine bug that
only the Z80 datalayout tickles, or a Z80-specific interaction.  (Routing per
CLAUDE.md `feedback_upstream_routing_two_targets` to be decided at filing time:
if it reproduces on a mainline target it belongs at llvm/llvm-project, not the
fork.)

## Reproducer

Self-contained preprocessed input `c90lib-lnlc-O2-crash.i` (in this dir):

```
clang --target=z80 -S -ffreestanding -std=gnu11 -O2 c90lib-lnlc-O2-crash.i -o /dev/null
# -> Segmentation fault: 11        (exit 139)
# -O0 and -O1 exit 0
```

Or from the vendored source through the z88dk pipeline:

```
cd support/benchmarks/stdcbench/src
zcc +cpm -compiler=llvmz80 -O2 -c c90lib-lnlc.c -o /dev/null   # crashes
```

## Notes toward a minimal repro (not yet reduced)

- The crashing function is `add()`.  It only crashes with the recursive
  isomorphism test `test()`/`permtest()` present in the same TU (they inline
  into `add()` before aggressive-instcombine runs); a hand-extracted `add()`
  with `test()` stubbed `extern` does NOT crash.  A faithful minimal repro
  therefore needs `add` + `test` + `permtest` + `recolor`/`maprecolor` and the
  handful of `node_t`/`count_t` globals they touch.
- `node_t` = `uint_least8_t`, `count_t` = `uint_fast8_t` (both 8-bit here);
  the function is dense in 8-bit index arithmetic, small fixed-size `memcpy`,
  and nested loops with `goto`.
- Next step when filing: run `llvm-reduce`/`cvise` against the `.i` with an
  interestingness test of "clang -O2 segfaults", to shrink to a few lines.
