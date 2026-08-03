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
NTVCM=/path/to/ntvcm ./compare.sh          # c90base (comparable headline)
NTVCM=/path/to/ntvcm MODULES=all ./compare.sh   # + c90lib (sdcc/sccz80 only)
```

`make sweep` / `make clean` wrap the same thing.

## Lanes

| lane        | compiler / convention                                  |
| ----------- | ------------------------------------------------------ |
| llvmz80-O2  | ravn/llvm-z80 GlobalISel clang, `-O2` (z80 16-bit ABI) |
| llvmz80-Os  | same, `-Os` (identical output to `-O2` on this load)   |
| sdcc0       | z88dk-zsdcc `-SO3`, `--sdcccall 0` (z88dk default)     |
| sdcc1       | z88dk-zsdcc `-SO3`, `--sdcccall 1` (PATH-shim inject)  |
| sccz80      | sccz80 `-O2`                                            |

## Results snapshot (2026-08-04, module set: c90base, @4 MHz)

| Compiler   | opt  | .COM bytes |         cycles | self-check |
| ---------- | ---- | ---------: | -------------: | ---------- |
| llvmz80-O2 | -O2  |      12624 |    414,888,705 | OK         |
| llvmz80-Os | -Os  |      12624 |    414,888,705 | OK         |
| sdcc0      | -SO3 |      12289 |    809,940,171 | OK         |
| sdcc1      | -SO3 |      12176 |              — | CHECK-FAIL |
| sccz80     | -O2  |      11499 |  1,350,010,977 | OK         |

Reading it: on the c90base integer workload **llvmz80 is ~1.95× faster than
sdcc (`--sdcccall 0`) and ~3.25× faster than sccz80**, at a modest size cost
(~3 % larger than sdcc0, ~10 % larger than sccz80).  Size and speed are
different axes — sccz80 is smallest but slowest.

### Caveats / known issues

- **sdcc1 (`--sdcccall 1`) CHECK-FAIL.** Under `--sdcccall 1` linked against
  z88dk's `--sdcccall 0` precompiled clib, `c90base_immul` and `c90base_isort`
  fail stdcbench's result validation (miscompile).  Not a trustworthy lane for
  this benchmark; kept in the table so the failure is visible, not hidden.
- **c90lib module blocked on the llvmz80 lane** (so the headline uses c90base
  only, symmetrically, to keep lanes comparable — stdcbench `RULES`):
  1. `c90lib-lnlc.c` → **clang backend segfault** at `-O2/-Os` in the
     `aggressive-instcombine` pass on function `add` (`-O0/-O1` fine).  See
     `bugs/README.md` + the self-contained `bugs/c90lib-lnlc-O2-crash.i`.
  2. `c90lib-peep.c` → **z88dk `z80asm` cannot parse** the large `.asciz`
     peephole-rules string clang emits (same class as the known
     `s_countLeadingZeros8.c` 256-byte-table limitation; only the llvmz80 path
     uses `z80asm`).
  Both compile fine under sdcc/sccz80, so `MODULES=all` exercises c90lib on
  those lanes.

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
