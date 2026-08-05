# stdcbench cross-compiler sweep (z88dk +cpm / Z80 / CP/M)

Measures the efficiency of **whole CP/M programs** — real `.COM` files linking
the full z88dk standard runtime — across every Z80 C compiler z88dk can drive,
using the standard **stdcbench** benchmark (Philipp Klaus Krause, SDCC
maintainer; "stdcbench - A Benchmark for Small Systems", SCOPES '18).

This complements `../dhrystone21/` (single benchmark, partly gameable) with a
modular, self-checking suite whose score no single function dominates.  Unlike
the earlier freestanding compiler sweep, every program here links the real
clib (printf/malloc/string), so the numbers reflect full-program density and
speed as an end user would see them.

## What it measures

Per compiler lane, for a **fixed, deterministic workload**:

- **`.COM` size (bytes)** — code-density axis.
- **cycles (T-states)** — speed axis, counted by `z88dk-ticks` between the
  `TIMER_START`/`TIMER_STOP` labels wrapped around the `stdcbench()` call.
- **self-check** — stdcbench's own per-module result validation, run under
  `ntvcm`.  A timing number is only trusted when this is `OK`.

### Timing model — no wall clock

The Z80/CP/M target has no readable clock (CP/M 2.2 has no timer; `ntvcm`
exposes no guest cycle counter), and a wall-clock timer would make the workload
host-speed-dependent and non-reproducible.  Instead:

- `src/portme.c`'s `stdcbench_clock()` is a **pure call-counter**, so
  stdcbench's "run until N clocks elapsed" loops execute a **fixed iteration
  count identical across every compiler** (it pins the amount of work, it does
  not time anything).
- The real, relative timer is **`z88dk-ticks`** — an external, cycle-exact,
  fully deterministic T-state count.  That is the speed metric.

So the same amount of work is compiled by each compiler; `ntvcm` proves it is
correct; `z88dk-ticks` measures what it costs.  (This is a documented
methodology change from stdcbench's wall-clock "score", per its `RULES`: we
report cycles for a fixed workload, which is more precise on an emulator.)

## Running

```
export LLVMZ80EXE=/path/to/llvm-z80/build-*/bin/clang    # for the llvmz80 lanes
export PATH=/path/to/z88dk/bin:$PATH
export ZCCCFG=/path/to/z88dk/lib/config
NTVCM=/path/to/ntvcm ./compare.sh          # c90base (all lanes) + c90lib (llvmz80)
NTVCM=/path/to/ntvcm MODULES=all ./compare.sh   # additionally c90lib on sdcc/sccz80
```

`make sweep` / `make clean` wrap the same thing.

## Lanes

| lane        | compiler / convention                                  |
| ----------- | ------------------------------------------------------ |
| llvmz80-O2  | ravn/llvm-z80 GlobalISel clang, `-O2` (z80 16-bit ABI; `-Os` is byte/cycle-identical on this load, so only `-O2` is run) |
| sdcc0       | z88dk-zsdcc `-SO3`, `--sdcccall 0` (z88dk default)     |
| sccz80      | sccz80 `-O2`                                            |

## Results snapshot (2026-08-04, module set: c90base, @4 MHz)

Fair comparison: every lane runs the **same** workload (c90base only), so this
isolates codegen.  llvmz80 is the fastest lane by ~2x, competitive on size.

| Compiler   | opt  | .COM bytes |         cycles | self-check |
| ---------- | ---- | ---------: | -------------: | ---------- |
| llvmz80-O2 | -O2  |      12784 |    414,888,705 | OK         |
| sdcc0      | -SO3 |      12289 |    809,940,171 | OK         |
| sccz80     | -O2  |      11499 |  1,350,010,977 | OK         |

llvmz80 opt-level scan (same c90base workload): `-O0` 13604 B / 1,166,665,008 cyc;
`-Os` == `-O2` 12784 B / 414,888,705 cyc; `-O3` 13263 B / 414,939,625 cyc (+479 B
over `-O2` for no measurable speed gain, so `-O2`/`-Os` is the sweet spot).
The `sdcc1` (`--sdcccall 1`) lane is dropped (always CHECK-FAIL, see caveats).

Reading it: on the c90base integer workload **llvmz80 is ~1.95× faster than
sdcc (`--sdcccall 0`) and ~3.25× faster than sccz80**, at a modest size cost
(~3 % larger than sdcc0, ~10 % larger than sccz80).  Size and speed are
different axes — sccz80 is smallest but slowest.

## Per-component breakdown (`make components` / `component_timing.sh`)

`compare.sh` times the whole suite; `component_timing.sh` isolates each
sub-benchmark (BENCH_COMPONENT mode of bench_main.c: run one sub-benchmark N
times — the same reps the driver uses, c90base 8×, c90lib 40× — gated on a
per-part `+cpm` COMPONENT-OK check).  The parts **reconcile to the whole**:
llvmz80 sum = 14,026,557,344 vs whole-suite 14,026,608,586 (0.0004 % apart),
which validates the numbers.

Per-component T-states (2026-08-04):

| component            | reps |     llvmz80 |       sdcc0 |      sccz80 |
| -------------------- | ---- | ----------: | ----------: | ----------: |
| c90base_compression  |    8 | 157,419,472 | 228,113,957 | 372,938,365 |
| c90base_isort        |    8 | 195,414,456 | 244,556,165 | 405,999,421 |
| c90base_immul        |    8 |  62,037,336 | 337,254,013 | 571,057,021 |
| c90lib_lnlc          |   40 | 8,604,360,200 | build-fail | build-fail  |
| c90lib_peep          |   40 | 5,007,325,880 | build-fail | build-fail  |

**Where the llvmz80 lead comes from:** almost entirely `c90base_immul`
(integer multiply).  Of the 395 M cycles llvmz80 saves over sdcc0 on c90base,
`immul` accounts for **69.7 %** (275 M; llvmz80 is 5.4× faster there),
`compression` 17.9 %, `isort` 12.4 %.  The other two components are modest wins
(1.25–1.45×).  On the full suite, c90lib dominates (lnlc alone ≈ 61 % of total
time); sdcc/sccz80 can't be compared there because they build-fail on c90lib
through this harness.

The `immul` gap is **not** primarily register allocation / memory traffic — it
is middle-end interprocedural optimization: clang inlines `imul_mm` and
constant-folds its compile-time-constant matrix product to nothing, while sdcc
re-runs it at runtime every iteration.  Full asm-backed analysis (with the
disproved hypotheses and a benchmark-artefact caveat): **[ANALYSIS-immul.md](ANALYSIS-immul.md)**.

**Full module set (c90base + c90lib) on llvmz80:** both llvmz80 lanes build and
run the complete benchmark green (`.COM` ~29822 B, self-check `OK`, `STDCBENCH
OK`, clean exit).  This exercises the full standard-library surface including
`malloc`/`calloc`/`realloc`/`free`, so llvmz80 now runs stdcbench end-to-end.

**"Full coverage" note — there is no float module to enable.**  stdcbench 0.8
implements only **two** modules, c90base and c90lib.  The other two, **c90float**
and **c90double**, are upstream placeholders marked `NOT YET IMPLEMENTED!` in
`src/README` (their bodies just `return 0`; the floating-point module is item #1
in `src/TODO`).  So c90base + c90lib **is** the complete implemented suite, and
running both green under llvmz80 is full stdcbench coverage — the float/double
modules are not disabled by a toolchain gap, they do not exist in the benchmark.
(llvmz80 `double` support does exist separately, via `../../../llvmz80-softfloat`
and `LLVMZ80RTLIB`, but stdcbench never calls it.)

### Caveats / known issues

- **sdcc1 (`--sdcccall 1`) lane dropped.** Under `--sdcccall 1` linked against
  z88dk's `--sdcccall 0` precompiled clib, `c90base_immul` and `c90base_isort`
  fail stdcbench's result validation (miscompile).  Not a trustworthy lane for
  this benchmark, so it is no longer built (removed from `LANES` in
  `compare.sh`); re-add the `sdcc1|...|1` entry if you want to see the failure.
- **c90lib now builds and runs on the llvmz80 lane** (full module set).  Both
  former llvmz80-specific blockers were fixed, and the dynamic-memory path is
  set up:
  1. `c90lib-lnlc.c` → the clang backend segfault at `-O2/-Os` in the
     `aggressive-instcombine` pass was fixed upstream in ravn/llvm-z80
     (`TruncInstCombine.cpp` cyclic-`and` rollback guard + lit test).  See
     `bugs/README.md` + the self-contained `bugs/c90lib-lnlc-O2-crash.i`.
  2. `c90lib-peep.c` → the z88dk `z80asm` `.asciz` overflow was fixed in
     `lib/llvmz80/splitascii.pl` (it now splits oversized `.asciz` as well as
     `.ascii`, same class as the `s_countLeadingZeros8.c` 256-byte-table limit).
  3. **Heap / dynamic memory** — c90lib uses `malloc`/`calloc`/`realloc`/`free`.
     `src/portme.h` sets `CLIB_MALLOC_HEAP_SIZE=16384` for `__LLVMZ80`, and
     `malloc.h` routes all four allocators to the register-ABI `*_callee` /
     `*_fastcall` entries.  `realloc` needed a reversed-arg macro swap
     (`realloc_callee(size, p)`) because clang pushes `__smallc __z88dk_callee`
     args right-to-left while the classic `_callee` asm expects left-to-right —
     the same per-function header-swap pattern z88dk already uses for
     `qsort`/`bsearch`.  Regression test: `test/clang/runtime_realloc.{c,sh}`.

  The other lanes still need `MODULES=all` to exercise c90lib.

## Layout

```
src/            vendored stdcbench 0.8 (GPL-2-or-later, see src/GPL-2) + the
                z88dk port: portme.h, portme.c, bench_main.c
compare.sh      build every lane, gate correctness, print the markdown table
Makefile        sweep / clean wrappers
bugs/           llvmz80 c90lib crash reproducer + writeup
```

## License

stdcbench is **GPL-2-or-later** (`src/GPL-2`).  Per its `RULES`, modified
versions must be marked as such: the z88dk port (`portme.*`, `bench_main.c`,
the deterministic call-counter clock, and the `STDCBENCH_CMP_CONV` /
`STDCBENCH_DISABLE_C90LIB` port hooks) is a modification for benchmarking under
z88dk `+cpm`; numbers here are **not** stdcbench's official wall-clock score.
