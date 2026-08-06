# stdcbench results (ravn/llvm-z80 clang, +cpm) — and how the score is computed

This documents the stdcbench numbers we get for the `-compiler=llvmz80` (classic
clib) path, and — importantly — **what the reported "score" actually measures in
this harness**, so nobody mistakes it for a wall-clock or instruction-count
performance figure. Short version: with the clock we use here the score is a
**deterministic constant that only certifies the benchmark ran to completion and
self-validated** — it is NOT a speed measurement.

## Measured numbers

Build + run (this workspace):

```
zcc +cpm -compiler=llvmz80 -O2 -create-app <all c90base + c90lib sources> -o stdcbench.com
ntvcm stdcbench.com
```

- stdcbench version: **0.8** (vendored under `src/`)
- Modules enabled: **c90base + c90lib** (`MODULES=all`; c90float / c90double are
  not implemented in 0.8)
- Compiler: ravn/llvm-z80 clang via `zcc +cpm -compiler=llvmz80 -O2`, default
  `-std=gnu23`
- Heap model: dynamic whole-TPA (`#pragma define CRT_STACK_SIZE=2048` in
  `portme.h`; requires the ravn/z88dk#40 `SECTION bss_stdlib` CRT fix)
- Platform: ntvcm (CP/M emulator), `.com` = 30496 B

Output:

```
stdcbench 0.8
stdcbench c90base score: 80
stdcbench c90lib score: 400
stdcbench final score: 480
STDCBENCH OK
```

`STDCBENCH OK` is stdcbench's own end-of-run self-validation (results verified
correct), not merely "it didn't crash".

## How the score is computed — and why 480 is a CONSTANT here

Each module runs a fixed unit of work in a `do { … } while` loop until the clock
advances by a per-module budget `SECONDS`, then computes a score. From
`c90base.c` / `c90lib.c`:

```c
#define SECONDS (STDCBENCH_CLOCKS_PER_SEC * 8ul)   /* c90base; c90lib uses *40 */

unsigned long iterations = 0;
stdcbench_clock_t start = stdcbench_clock();
do {
        /* ... one unit of benchmark work ... */
        iterations++;
} while ((end = stdcbench_clock()) - start < SECONDS);

return iterations * (1000 * SECONDS / (end - start)) / 100;
```

On a **real** platform `stdcbench_clock()` is a wall clock, so more iterations fit
in the `SECONDS` budget on a faster machine, and the returned score scales with
speed.

**In this harness it does not.** Our `portme.c` implements the clock as a pure
call-counter:

```c
stdcbench_clock_t stdcbench_clock(void) { static stdcbench_clock_t ticks; return (++ticks); }
```

with `STDCBENCH_CLOCKS_PER_SEC = 1` (`portme.h`). Because the loop calls
`stdcbench_clock()` exactly once per iteration (in the `while` test) and nothing
else calls it, the clock advances by exactly 1 per iteration. So:

- `end - start == iterations`, and the loop stops the first time that reaches
  `SECONDS` → **`iterations == SECONDS`** every run, on every machine.
- The score formula then collapses:
  `iterations * (1000 * SECONDS / (end - start)) / 100`
  `= SECONDS * (1000 * SECONDS / SECONDS) / 100`
  `= SECONDS * 1000 / 100`
  `= SECONDS * 10`.

Worked out with the real constants:

| Module   | `SECONDS` (`CLOCKS_PER_SEC=1`) | iterations run | score = `SECONDS*10` |
|----------|-------------------------------|----------------|----------------------|
| c90base  | `1 * 8`  = 8                  | 8              | **80**               |
| c90lib   | `1 * 40` = 40                | 40             | **400**              |
| **final**|                               |                | **480**              |

So **480 is a fixed constant fixed entirely by the two loop-budget constants
(8 and 40)**. It is:

- **NOT wall-clock time** — the clock is a call counter, not a timer.
- **NOT an instruction / T-state count** — the reported number never sees the
  real cost of the work; a faster or slower code generator produces the *same*
  480.
- It DOES prove the enabled modules execute their fixed iteration count to
  completion and pass stdcbench's internal correctness checks (`STDCBENCH OK`).
  That is exactly what we use it for: a deterministic pass/fail signal that
  finishes within a sane emulator ticks budget (see `portme.h` header comment
  and `bugs/FINDINGS-issue40-dynamic-heap-qsort-corruption.md`).

### Why it is set up this way

A real wall clock under an emulator would make the run length depend on
host/emulator speed and the iteration count non-deterministic, which is bad for a
CI-style correctness gate. The call-counter clock makes the run a fixed,
reproducible amount of work whose only variable outcome is pass/fail. Actual
performance is measured separately (below), not through this score.

## Getting a REAL, comparable number

To measure real performance, count Z80 T-states (proportional to time at a fixed
CPU clock) with `z88dk-ticks` between the `TIMER_START` / `TIMER_STOP` labels in
`bench_main.c` (the `BENCH_TIMER` build), instead of reading the constant score.
T-states are a reproducible, host-independent cost metric and are the right basis
for comparing clang-z80 against zsdcc / sccz80 on the same sources. See
`component_timing.sh` and `compare.sh` for the timing lanes.

## On comparing to published stdcbench results

stdcbench is a real published benchmark (Philipp K. Krause, *"stdcbench – A
Benchmark for Small Systems"*, SCOPES '18; homepage stdcbench.org / SourceForge),
but there is **no central public scoreboard** — results are scattered across the
author's papers and per-board tutorials. The one concrete public 8-bit figure we
found is an STM8 + SDCC tutorial (colecovision.eu) reporting **stdcbench 0.6 →
c90base 118 / c90lib 91 / final 209**. That is **not comparable** to our 480:
different stdcbench version (0.6 vs 0.8, different c90lib weighting), different
architecture, and — decisively — that run used a real timer while ours uses the
call-counter clock described above. Per stdcbench's own `RULES`, a comparable
report requires the same version, the same modules, a real clock, and full
hardware/clock disclosure.
